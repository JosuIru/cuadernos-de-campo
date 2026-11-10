import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../sonido/bufer_ultimos_segundos.dart';
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

  /// Cada bloque del micrófono, en bruto (aviso de calidad y barrido de
  /// rumbo). Se llama en el hilo principal: debe ser barato.
  final void Function(Float32List muestras, int frecuenciaHz)? alRecibirAudio;

  AudioRecorder? _grabadora;
  BuferCircularAudio? _buferUltimoOido;
  final RegistroTramosAnalizados _registroTramos = RegistroTramosAnalizados();
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
    this.alRecibirAudio,
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
        // Se guardan 5 s más que el clip: lo más nuevo aún no se ha analizado
        // y no puede entrar, así que sin ese margen el clip limpio no
        // llegaría a los 10 s.
        _buferUltimoOido = BuferCircularAudio(
            ((segundosBuferUltimoOido + segundosMargenSinAnalizar) * frecuenciaHz).round());
        _registroTramos.vaciar();
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
    final muestras = pcm16ABloqueFlotante(bytes);
    recolector.anadirMuestras(muestras);
    _buferUltimoOido?.anadir(muestras);
    alRecibirAudio?.call(muestras, _frecuenciaMicrofonoHz);
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

  /// Apunta si un trozo analizado tenía voz humana: del búfer de lo último
  /// oído solo sale audio analizado y limpio.
  void registrarTrozoAnalizado(TrozoAnalizado trozo, {required bool conVozHumana}) {
    final recolector = _recolector;
    final bufer = _buferUltimoOido;
    if (recolector == null || bufer == null) return;
    _registroTramos.registrar(
      trozo.muestraFinalMicrofono - recolector.muestrasPorVentana,
      trozo.muestraFinalMicrofono,
      conVozHumana: conVozHumana,
    );
    _registroTramos.olvidarAnterioresA(bufer.primeraMuestraDisponible);
  }

  /// Lo último oído (hasta 10 s) que ya se ha analizado sin voz humana, a la
  /// frecuencia del micrófono; null si no hay.
  ({Float32List muestras, int frecuenciaHz})? ultimoOidoLimpio() {
    final bufer = _buferUltimoOido;
    if (bufer == null || _frecuenciaMicrofonoHz <= 0) return null;
    final tramo = _registroTramos.ultimoTramoLimpio(
      maximoMuestras: (segundosBuferUltimoOido * _frecuenciaMicrofonoHz).round(),
      primeraDisponible: bufer.primeraMuestraDisponible,
      huecoTolerado: (segundosHuecoToleradoEntreTrozos * _frecuenciaMicrofonoHz).round(),
    );
    if (tramo == null) return null;
    final muestras = bufer.extraer(tramo.inicio, tramo.fin);
    if (muestras == null) return null;
    return (muestras: muestras, frecuenciaHz: _frecuenciaMicrofonoHz);
  }

  /// Cierra el micrófono. Se puede llamar varias veces.
  Future<void> detener() async {
    _detenida = true;
    final suscripcion = _suscripcion;
    final grabadora = _grabadora;
    _suscripcion = null;
    _grabadora = null;
    _recolector = null;
    _buferUltimoOido = null;
    _registroTramos.vaciar();
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
