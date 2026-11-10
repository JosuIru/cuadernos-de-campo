import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../sonido/ventanas_audio.dart';
import 'clasificador_fauna.dart';

/// Un trozo de 5 s ya analizado.
class TrozoAnalizado {
  final TrozoClasificado clasificado;

  /// Hora del final del trozo.
  final DateTime momentoFinal;

  /// Muestras de micrófono recibidas hasta el final del trozo (para saber
  /// cuánto separa dos trozos al componer el clip).
  final int muestraFinalMicrofono;
  final int frecuenciaMicrofonoHz;
  final double saltoSegundos;
  final double nivelDecibelios;

  const TrozoAnalizado({
    required this.clasificado,
    required this.momentoFinal,
    required this.muestraFinalMicrofono,
    required this.frecuenciaMicrofonoHz,
    required this.saltoSegundos,
    required this.nivelDecibelios,
  });
}

/// Frecuencias que se piden al micrófono, por orden. 48 kHz la admite casi
/// cualquier Android; 44,1 kHz es la única que garantiza la plataforma.
const List<int> _frecuenciasMicrofonoHz = [48000, 44100];

/// Escucha el micrófono sin parar y, cada 2,5 s (o 5 s si el móvil va
/// justo), pasa los últimos 5 s al modelo. Mientras se analiza un trozo no
/// se empieza otro: si el análisis se retrasa, se salta al más reciente. El
/// audio solo vive en memoria. Portado de `useWildlifeListener.ts`.
class EscuchaMicrofonoFauna {
  final ClasificadorFauna clasificador;
  final void Function(TrozoAnalizado trozo) alAnalizarTrozo;
  final void Function(String mensaje) alFallarAnalisis;

  AudioRecorder? _grabadora;
  StreamSubscription<Uint8List>? _suscripcion;
  RecolectorVentanasAudio? _recolector;
  int _frecuenciaMicrofonoHz = 0;
  bool _analizando = false;
  bool _detenida = true;
  int? _milisegundosUltimoAnalisis;
  int? _byteSobrante;

  EscuchaMicrofonoFauna({
    required this.clasificador,
    required this.alAnalizarTrozo,
    required this.alFallarAnalisis,
  });

  bool get escuchando => !_detenida;
  int get frecuenciaMicrofonoHz => _frecuenciaMicrofonoHz;
  int? get milisegundosUltimoAnalisis => _milisegundosUltimoAnalisis;
  double get saltoActualSegundos => elegirSaltoSegundos(_milisegundosUltimoAnalisis);

  /// Abre el micrófono. El permiso se pide antes, en la pantalla. Lanza si
  /// no se puede abrir.
  Future<void> empezar() async {
    if (!_detenida) return;
    _detenida = false;
    final grabadora = AudioRecorder();
    _grabadora = grabadora;
    Object? ultimoError;
    for (final frecuenciaHz in _frecuenciasMicrofonoHz) {
      try {
        final flujo = await grabadora.startStream(RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: frecuenciaHz,
          numChannels: 1,
          // Sin control de ganancia, cancelación de eco ni supresión de
          // ruido: estropean el canto (lo que el modelo necesita oír).
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ));
        if (_detenida) {
          await grabadora.stop();
          return;
        }
        _frecuenciaMicrofonoHz = frecuenciaHz;
        final segundosVentana =
            clasificador.manifiesto.muestrasVentana / clasificador.manifiesto.frecuenciaMuestreoHz;
        _recolector = RecolectorVentanasAudio((segundosVentana * frecuenciaHz).round());
        _suscripcion = flujo.listen(_recibirBloque, onError: (Object error) {
          alFallarAnalisis(error.toString());
        });
        return;
      } catch (error) {
        ultimoError = error;
        try {
          await grabadora.stop();
        } catch (_) {}
      }
    }
    await detener();
    throw StateError('No se ha podido abrir el micrófono: $ultimoError');
  }

  void _recibirBloque(Uint8List bloque) {
    final recolector = _recolector;
    if (_detenida || recolector == null) return;
    // Un bloque con un número impar de bytes deja media muestra para el
    // siguiente.
    var bytes = bloque;
    if (_byteSobrante != null) {
      bytes = Uint8List(bloque.length + 1)
        ..[0] = _byteSobrante!
        ..setRange(1, bloque.length + 1, bloque);
      _byteSobrante = null;
    }
    if (bytes.length.isOdd) {
      _byteSobrante = bytes.last;
      bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    }
    recolector.anadirMuestras(pcm16ABloqueFlotante(bytes));
    if (_analizando) return;
    final saltoSegundos = elegirSaltoSegundos(_milisegundosUltimoAnalisis);
    final trozo = recolector.tomarVentanaSiLista((saltoSegundos * _frecuenciaMicrofonoHz).round());
    if (trozo != null) {
      unawaited(_analizar(trozo, saltoSegundos, recolector.muestrasRecibidasTotales));
    }
  }

  Future<void> _analizar(Float32List trozo, double saltoSegundos, int muestraFinal) async {
    _analizando = true;
    final momentoFinal = DateTime.now();
    try {
      final clasificado = await clasificador.clasificar(trozo, _frecuenciaMicrofonoHz);
      _milisegundosUltimoAnalisis = clasificado.milisegundosTotales;
      if (_detenida) return;
      alAnalizarTrozo(TrozoAnalizado(
        clasificado: clasificado,
        momentoFinal: momentoFinal,
        muestraFinalMicrofono: muestraFinal,
        frecuenciaMicrofonoHz: _frecuenciaMicrofonoHz,
        saltoSegundos: saltoSegundos,
        nivelDecibelios: nivelRmsDecibelios(clasificado.trozoModelo),
      ));
    } catch (error) {
      if (!_detenida) alFallarAnalisis(error.toString());
    } finally {
      _analizando = false;
    }
  }

  /// Cierra el micrófono. Se puede llamar varias veces.
  Future<void> detener() async {
    _detenida = true;
    final suscripcion = _suscripcion;
    final grabadora = _grabadora;
    _suscripcion = null;
    _grabadora = null;
    _recolector = null;
    _byteSobrante = null;
    await suscripcion?.cancel();
    if (grabadora != null) {
      try {
        await grabadora.stop();
      } catch (_) {}
      try {
        await grabadora.dispose();
      } catch (_) {}
    }
  }
}
