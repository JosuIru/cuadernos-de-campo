import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../sonido/clasificacion_sonido.dart';
import '../sonido/clip_audio.dart';
import '../sonido/manifiesto_modelo_fauna.dart';
import '../sonido/registro_sesion_sonora.dart';
import '../sonido/sesion_escucha.dart';

/// Cada cuánto se guarda la traza mientras se camina (por si la app muere).
const Duration intervaloGuardadoTraza = Duration(seconds: 30);

/// Una sesión larga en marcha («Escuchar mientras camino» o «Coro del
/// amanecer»). Recibe los trozos ya analizados de la pantalla de escucha,
/// apunta cada especie mostrada como detección (en la BD al momento) con el
/// punto de la traza y guarda en memoria el mejor clip de cada especie; al
/// terminar escribe esos clips (uno por especie) en `audios/`. Nunca guarda
/// audio continuo.
class ControladorSesionSonora extends ChangeNotifier {
  final TipoSesionSonora tipo;
  final String versionModelo;
  final bool conFiltroDeZona;
  final DateTime? finPrevisto;

  ControladorSesionSonora({
    required this.tipo,
    required this.versionModelo,
    required this.conFiltroDeZona,
    this.finPrevisto,
  });

  int? _sesionId;
  late DateTime _inicio;
  final List<PuntoTrazaSonora> _traza = [];
  final SesionEscucha _mejoresClips = SesionEscucha();
  final Map<String, ({int? id, double puntuacion})> _mejorDeteccionPorEspecie = {};
  final Set<String> _especies = {};
  int _numeroDetecciones = 0;
  StreamSubscription<Position>? _suscripcionGps;
  Timer? _temporizadorTraza;
  Future<void> _colaEscrituras = Future.value();
  bool _pausada = false;
  bool _terminada = false;
  String? _errorGps;

  int? get sesionId => _sesionId;
  DateTime get inicio => _inicio;
  bool get pausada => _pausada;
  bool get terminada => _terminada;
  int get numeroDetecciones => _numeroDetecciones;
  int get numeroEspecies => _especies.length;
  int get puntosTraza => _traza.length;
  String? get errorGps => _errorGps;
  double get distanciaMetros => distanciaTrazaMetros(_traza);
  PuntoTrazaSonora? get ultimoPunto => _traza.isEmpty ? null : _traza.last;

  /// Crea la sesión en la BD y, en un recorrido, empieza la traza GPS (en un
  /// coro, una sola posición: la del sitio de escucha). El permiso de
  /// ubicación se pide antes, en la pantalla; sin él la sesión sigue, sin
  /// posiciones.
  Future<void> empezar({required bool conUbicacion}) async {
    _inicio = DateTime.now();
    _sesionId = await BaseDatosNaturaleza.instancia.crearSesionSonora(SesionSonora(
      tipo: tipo,
      inicioMs: _inicio.millisecondsSinceEpoch,
      finPrevistoMs: finPrevisto?.millisecondsSinceEpoch,
      versionModelo: versionModelo,
      conFiltroDeZona: conFiltroDeZona,
    ));
    if (conUbicacion) _empezarUbicacion();
    notifyListeners();
  }

  void _empezarUbicacion() {
    if (tipo == TipoSesionSonora.coro) {
      if (_traza.isNotEmpty) return;
      unawaited(() async {
        try {
          final posicion = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 30),
          );
          _anadirPunto(posicion);
          _guardarTraza();
        } catch (error) {
          _errorGps = '$error';
          notifyListeners();
        }
      }());
      return;
    }
    // La pantalla está encendida y abierta: basta el flujo normal, sin
    // servicio en primer plano.
    _suscripcionGps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(_anadirPunto, onError: (Object error) {
      _errorGps = '$error';
      notifyListeners();
    });
    _temporizadorTraza = Timer.periodic(intervaloGuardadoTraza, (_) => _guardarTraza());
  }

  void _anadirPunto(Position posicion) {
    _traza.add(PuntoTrazaSonora(
      momentoMs: DateTime.now().millisecondsSinceEpoch,
      latitud: posicion.latitude,
      longitud: posicion.longitude,
      precisionMetros: posicion.accuracy,
    ));
    _errorGps = null;
    notifyListeners();
  }

  void _guardarTraza() {
    final id = _sesionId;
    if (id == null) return;
    final copia = List<PuntoTrazaSonora>.of(_traza);
    _encolar(() => BaseDatosNaturaleza.instancia.actualizarSesionSonora(id, traza: copia));
  }

  void _encolar(Future<void> Function() escritura) {
    _colaEscrituras = _colaEscrituras.then((_) => escritura()).catchError((_) {});
  }

  /// Un trozo limpio con las especies mostradas como resultado.
  void registrarTrozo({
    required List<ClaseClasificada> especiesMostradas,
    required List<ClaseSonido> clases,
    required DateTime momento,
    required String Function(ClaseSonido clase) nombreComunDe,
    Int16List? clip,
  }) {
    final sesionId = _sesionId;
    if (sesionId == null || _pausada || _terminada || especiesMostradas.isEmpty) return;
    _mejoresClips.registrarTrozo(especiesMostradas: especiesMostradas, momento: momento, clip: clip);
    final momentoMs = momento.millisecondsSinceEpoch;
    final indicePunto = indicePuntoTrazaPara(_traza, momentoMs);
    final punto = indicePunto == null ? null : _traza[indicePunto];
    for (final clasificada in especiesMostradas) {
      if (clasificada.indiceClase < 0 || clasificada.indiceClase >= clases.length) continue;
      final clase = clases[clasificada.indiceClase];
      final deteccion = DeteccionSonora(
        sesionId: sesionId,
        momentoMs: momentoMs,
        etiqueta: clase.etiqueta,
        nombreComun: nombreComunDe(clase),
        categoria: especieGuiaPorNombreCientifico(clase.etiqueta)?.categoriaId ??
            clase.grupo?.categoriaNaturaleza ??
            'animal',
        puntuacion: clasificada.puntuacion,
        puntuacionModelo: clasificada.puntuacionModelo,
        latitud: punto?.latitud,
        longitud: punto?.longitud,
        indicePuntoTraza: indicePunto,
      );
      _numeroDetecciones++;
      _especies.add(clase.etiqueta);
      final etiqueta = clase.etiqueta;
      final anterior = _mejorDeteccionPorEspecie[etiqueta];
      final esMejor = anterior == null || clasificada.puntuacion > anterior.puntuacion;
      if (esMejor) _mejorDeteccionPorEspecie[etiqueta] = (id: null, puntuacion: clasificada.puntuacion);
      _encolar(() async {
        final id = await BaseDatosNaturaleza.instancia.guardarDeteccionSonora(deteccion);
        final actual = _mejorDeteccionPorEspecie[etiqueta];
        if (esMejor && actual != null && actual.puntuacion == clasificada.puntuacion && actual.id == null) {
          _mejorDeteccionPorEspecie[etiqueta] = (id: id, puntuacion: clasificada.puntuacion);
        }
      });
    }
    notifyListeners();
  }

  /// La escucha se ha parado sin terminar (app en segundo plano): se deja
  /// de seguir la posición y se espera a «Continuar» o «Terminar».
  void pausar() {
    if (_terminada || _pausada) return;
    _pausada = true;
    _pararUbicacion();
    _guardarTraza();
    notifyListeners();
  }

  void continuar({required bool conUbicacion}) {
    if (_terminada || !_pausada) return;
    _pausada = false;
    if (conUbicacion) _empezarUbicacion();
    notifyListeners();
  }

  void _pararUbicacion() {
    unawaited(_suscripcionGps?.cancel());
    _suscripcionGps = null;
    _temporizadorTraza?.cancel();
    _temporizadorTraza = null;
  }

  /// Cierra la sesión: escribe el mejor clip de cada especie, guarda la
  /// traza y la hora de fin. Devuelve el id de la sesión.
  Future<int?> terminar({required List<ClaseSonido> clases, required int frecuenciaClipHz}) async {
    final sesionId = _sesionId;
    if (_terminada) return sesionId;
    _terminada = true;
    _pararUbicacion();
    await _colaEscrituras;
    if (sesionId == null) return null;
    try {
      final documentos = await getApplicationDocumentsDirectory();
      final carpeta = Directory(path_lib.join(documentos.path, 'audios'));
      await carpeta.create(recursive: true);
      for (final especie in _mejoresClips.especiesPorPuntuacion) {
        final clip = especie.clipMejor;
        if (clip == null || especie.indiceClase >= clases.length) continue;
        final etiqueta = clases[especie.indiceClase].etiqueta;
        final mejor = _mejorDeteccionPorEspecie[etiqueta];
        if (mejor?.id == null) continue;
        final fichero = File(path_lib.join(carpeta.path, 'sesion_${sesionId}_${especie.indiceClase}.wav'));
        await fichero.writeAsBytes(codificarWavMono16(clip, frecuenciaClipHz), flush: true);
        await BaseDatosNaturaleza.instancia.actualizarDeteccionSonora(mejor!.id!, {'ruta_clip': fichero.path});
      }
    } catch (_) {
      // Sin clips la sesión sigue valiendo (las detecciones ya están).
    }
    _mejoresClips.vaciar();
    await BaseDatosNaturaleza.instancia
        .actualizarSesionSonora(sesionId, finMs: DateTime.now().millisecondsSinceEpoch, traza: _traza);
    notifyListeners();
    return sesionId;
  }

  @override
  void dispose() {
    _pararUbicacion();
    super.dispose();
  }
}
