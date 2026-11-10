import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../sonido/manifiesto_modelo_fauna.dart';
import '../sonido/remuestreo_audio.dart';

/// Envoltorio del modelo LiteRT (paquete `tflite_flutter`, LiteRT 1.4 en
/// Android). Todo el trabajo pesado (remuestrear 5 s y pasar el modelo) se
/// hace en un isolate propio para no bloquear la interfaz; el modelo se
/// carga una vez al abrir la pantalla y se libera al salir.

class TrozoClasificado {
  /// Puntuaciones del modelo, en el orden de las clases del manifiesto.
  final Float32List logits;

  /// Log-mel, [tramasEspectrograma] × [bandasEspectrograma], trama a trama.
  final Float32List espectrograma;
  final int tramasEspectrograma;
  final int bandasEspectrograma;

  /// El trozo ya remuestreado a la frecuencia del modelo (para el clip).
  final Float32List trozoModelo;

  /// Embedding de Perch 2.0 (1536 valores), para «Tus sonidos».
  final Float32List embedding;
  final int milisegundosRemuestreo;
  final int milisegundosModelo;

  const TrozoClasificado({
    required this.logits,
    required this.espectrograma,
    required this.tramasEspectrograma,
    required this.bandasEspectrograma,
    required this.trozoModelo,
    required this.embedding,
    required this.milisegundosRemuestreo,
    required this.milisegundosModelo,
  });

  int get milisegundosTotales => milisegundosRemuestreo + milisegundosModelo;
}

class ClasificadorFauna {
  final ManifiestoFauna manifiesto;
  final Isolate _isolate;
  final SendPort _puertoEnvio;
  final ReceivePort _puertoRespuesta;
  final IndicesSalidaModelo _indicesSalida;
  final Map<int, Completer<Object?>> _peticionesPendientes;
  int _siguienteIdPeticion = 0;
  bool _liberado = false;

  ClasificadorFauna._(
    this.manifiesto,
    this._isolate,
    this._puertoEnvio,
    this._puertoRespuesta,
    this._indicesSalida,
    this._peticionesPendientes,
  );

  /// Carga el modelo en un isolate nuevo. Lanza si no se puede cargar o si
  /// sus salidas no casan con el manifiesto.
  static Future<ClasificadorFauna> cargar(ManifiestoFauna manifiesto, String rutaModelo) async {
    final puertoRespuesta = ReceivePort();
    final peticionesPendientes = <int, Completer<Object?>>{};
    final puertoEnvioCompleter = Completer<SendPort>();
    final cargaCompleter = Completer<List<List<int>>>();
    puertoRespuesta.listen((mensaje) {
      if (mensaje is SendPort) {
        puertoEnvioCompleter.complete(mensaje);
      } else if (mensaje is _RespuestaCarga) {
        if (mensaje.error != null) {
          cargaCompleter.completeError(StateError(mensaje.error!));
        } else {
          cargaCompleter.complete(mensaje.formasSalida);
        }
      } else if (mensaje is _RespuestaClasificacion) {
        final completer = peticionesPendientes.remove(mensaje.idPeticion);
        if (completer == null) return;
        if (mensaje.error != null) {
          completer.completeError(StateError(mensaje.error!));
        } else {
          completer.complete(mensaje);
        }
      }
    });
    final isolate = await Isolate.spawn(_principalIsolate, puertoRespuesta.sendPort,
        debugName: 'clasificador_fauna');
    try {
      final puertoEnvio = await puertoEnvioCompleter.future;
      puertoEnvio.send(_PeticionCarga(rutaModelo));
      final formasSalida = await cargaCompleter.future;
      final indicesSalida = resolverIndicesSalida(formasSalida, manifiesto);
      return ClasificadorFauna._(manifiesto, isolate, puertoEnvio, puertoRespuesta, indicesSalida,
          peticionesPendientes);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      puertoRespuesta.close();
      rethrow;
    }
  }

  /// Remuestrea [trozoMicrofono] (a [frecuenciaMicrofonoHz]) a la frecuencia
  /// del modelo y lo clasifica.
  Future<TrozoClasificado> clasificar(Float32List trozoMicrofono, int frecuenciaMicrofonoHz) async {
    if (_liberado) throw StateError('El modelo ya se ha liberado');
    final idPeticion = _siguienteIdPeticion++;
    final completer = Completer<Object?>();
    _peticionesPendientes[idPeticion] = completer;
    _puertoEnvio.send(_PeticionClasificacion(
      idPeticion: idPeticion,
      trozo: TransferableTypedData.fromList([trozoMicrofono]),
      frecuenciaMicrofonoHz: frecuenciaMicrofonoHz,
      frecuenciaModeloHz: manifiesto.frecuenciaMuestreoHz,
      muestrasModelo: manifiesto.muestrasVentana,
      indiceLogits: _indicesSalida.logits,
      indiceEspectrograma: _indicesSalida.espectrograma,
      indiceEmbedding: _indicesSalida.embedding,
    ));
    final respuesta = await completer.future as _RespuestaClasificacion;
    return TrozoClasificado(
      logits: respuesta.logits!.materialize().asFloat32List(),
      espectrograma: respuesta.espectrograma!.materialize().asFloat32List(),
      tramasEspectrograma: respuesta.tramasEspectrograma,
      bandasEspectrograma: respuesta.bandasEspectrograma,
      trozoModelo: respuesta.trozoModelo!.materialize().asFloat32List(),
      embedding: respuesta.embedding?.materialize().asFloat32List() ?? Float32List(0),
      milisegundosRemuestreo: respuesta.milisegundosRemuestreo,
      milisegundosModelo: respuesta.milisegundosModelo,
    );
  }

  void liberar() {
    if (_liberado) return;
    _liberado = true;
    _puertoEnvio.send(const _PeticionCierre());
    for (final completer in _peticionesPendientes.values) {
      completer.completeError(StateError('El modelo se ha liberado'));
    }
    _peticionesPendientes.clear();
    // Margen para que el isolate cierre el intérprete antes de matarlo.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      _isolate.kill();
      _puertoRespuesta.close();
    });
  }
}

class _PeticionCarga {
  final String rutaModelo;
  const _PeticionCarga(this.rutaModelo);
}

class _RespuestaCarga {
  final List<List<int>> formasSalida;
  final String? error;
  const _RespuestaCarga(this.formasSalida, [this.error]);
}

class _PeticionClasificacion {
  final int idPeticion;
  final TransferableTypedData trozo;
  final int frecuenciaMicrofonoHz;
  final int frecuenciaModeloHz;
  final int muestrasModelo;
  final int indiceLogits;
  final int indiceEspectrograma;
  final int indiceEmbedding;
  const _PeticionClasificacion({
    required this.idPeticion,
    required this.trozo,
    required this.frecuenciaMicrofonoHz,
    required this.frecuenciaModeloHz,
    required this.muestrasModelo,
    required this.indiceLogits,
    required this.indiceEspectrograma,
    required this.indiceEmbedding,
  });
}

class _RespuestaClasificacion {
  final int idPeticion;
  final TransferableTypedData? logits;
  final TransferableTypedData? espectrograma;
  final int tramasEspectrograma;
  final int bandasEspectrograma;
  final TransferableTypedData? trozoModelo;
  final TransferableTypedData? embedding;
  final int milisegundosRemuestreo;
  final int milisegundosModelo;
  final String? error;
  const _RespuestaClasificacion({
    required this.idPeticion,
    this.logits,
    this.espectrograma,
    this.tramasEspectrograma = 0,
    this.bandasEspectrograma = 0,
    this.trozoModelo,
    this.embedding,
    this.milisegundosRemuestreo = 0,
    this.milisegundosModelo = 0,
    this.error,
  });
}

class _PeticionCierre {
  const _PeticionCierre();
}

/// Copia los datos de un tensor de salida float32 (la memoria del tensor se
/// reutiliza en la siguiente inferencia).
Float32List _copiarSalidaFlotante(Tensor tensor) {
  final bytes = Uint8List.fromList(tensor.data);
  return bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
}

Future<void> _principalIsolate(SendPort puertoPrincipal) async {
  final puertoEntrada = ReceivePort();
  puertoPrincipal.send(puertoEntrada.sendPort);
  Interpreter? interprete;
  await for (final mensaje in puertoEntrada) {
    if (mensaje is _PeticionCarga) {
      try {
        final opciones = InterpreterOptions()..threads = Platform.numberOfProcessors.clamp(1, 4);
        interprete = Interpreter.fromFile(File(mensaje.rutaModelo), options: opciones);
        interprete.allocateTensors();
        final formas = [for (final tensor in interprete.getOutputTensors()) tensor.shape];
        puertoPrincipal.send(_RespuestaCarga(formas));
      } catch (error) {
        puertoPrincipal.send(_RespuestaCarga(const [], error.toString()));
      }
    } else if (mensaje is _PeticionClasificacion) {
      final interpreteCargado = interprete;
      if (interpreteCargado == null) {
        puertoPrincipal.send(_RespuestaClasificacion(
            idPeticion: mensaje.idPeticion, error: 'El modelo no está cargado'));
        continue;
      }
      try {
        final cronometro = Stopwatch()..start();
        final trozoMicrofono = mensaje.trozo.materialize().asFloat32List();
        final trozoModelo = remuestrearConPasoBajo(
          trozoMicrofono,
          mensaje.frecuenciaMicrofonoHz,
          mensaje.frecuenciaModeloHz,
          longitudSalida: mensaje.muestrasModelo,
        );
        final milisegundosRemuestreo = cronometro.elapsedMilliseconds;
        cronometro.reset();
        interpreteCargado.getInputTensor(0).data = trozoModelo.buffer.asUint8List();
        interpreteCargado.invoke();
        final milisegundosModelo = cronometro.elapsedMilliseconds;
        final logits = _copiarSalidaFlotante(interpreteCargado.getOutputTensor(mensaje.indiceLogits));
        final tensorEspectrograma = interpreteCargado.getOutputTensor(mensaje.indiceEspectrograma);
        final formaEspectrograma =
            tensorEspectrograma.shape.where((dimension) => dimension != 1).toList();
        final espectrograma = _copiarSalidaFlotante(tensorEspectrograma);
        final embedding = _copiarSalidaFlotante(interpreteCargado.getOutputTensor(mensaje.indiceEmbedding));
        puertoPrincipal.send(_RespuestaClasificacion(
          idPeticion: mensaje.idPeticion,
          logits: TransferableTypedData.fromList([logits]),
          espectrograma: TransferableTypedData.fromList([espectrograma]),
          tramasEspectrograma: formaEspectrograma.isNotEmpty ? formaEspectrograma[0] : 0,
          bandasEspectrograma: formaEspectrograma.length > 1 ? formaEspectrograma[1] : 0,
          trozoModelo: TransferableTypedData.fromList([trozoModelo]),
          embedding: TransferableTypedData.fromList([embedding]),
          milisegundosRemuestreo: milisegundosRemuestreo,
          milisegundosModelo: milisegundosModelo,
        ));
      } catch (error) {
        puertoPrincipal
            .send(_RespuestaClasificacion(idPeticion: mensaje.idPeticion, error: error.toString()));
      }
    } else if (mensaje is _PeticionCierre) {
      try {
        interprete?.close();
      } catch (_) {}
      interprete = null;
      puertoEntrada.close();
    }
  }
}
