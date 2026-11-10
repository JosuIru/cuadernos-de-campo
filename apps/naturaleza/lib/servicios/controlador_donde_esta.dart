import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sonido/barrido_rumbo.dart';
import '../sonido/triangulacion_rumbos.dart';
import 'brujula_rumbo.dart';

/// Estado de «¿Dónde está?» en la pantalla de escucha: tomas de rumbo
/// («Viene de aquí»), barrido y la zona estimada. Las tomas viven en memoria
/// mientras la pantalla está abierta; solo se guardan, con la zona, dentro
/// del hallazgo que se anote.

const _clavePreferenciaIncertidumbre = 'nat.quien_canta.incertidumbre_rumbo';

/// Opciones de margen de error por toma que ofrece la pantalla.
const List<double> opcionesIncertidumbreGrados = [5, 10, 15, 20];

enum ErrorTomaRumbo { sinPermisoUbicacion, sinPosicion, sinBrujula }

class ControladorDondeEsta extends ChangeNotifier {
  late final LectorBrujula _brujula = LectorBrujula(alLeer: (_) => _avisarConPausa());
  final List<TomaRumbo> _tomas = [];
  double _incertidumbreGrados = incertidumbrePorDefectoGrados;
  double? _declinacionGrados;
  bool _declinacionConsultada = false;
  bool _tomandoPosicion = false;
  ErrorTomaRumbo? _ultimoError;
  ZonaEstimada _zona = estimarZona(const []);
  bool _activo = false;
  bool _liberado = false;
  DateTime _ultimoAviso = DateTime.fromMillisecondsSinceEpoch(0);

  // Barrido
  bool _barriendo = false;
  final List<MuestraBarrido> _muestrasBarrido = [];
  ResultadoBarrido? _ultimoBarrido;

  List<TomaRumbo> get tomas => List.unmodifiable(_tomas);
  double get incertidumbreGrados => _incertidumbreGrados;
  bool get tomandoPosicion => _tomandoPosicion;
  ErrorTomaRumbo? get ultimoError => _ultimoError;
  ZonaEstimada get zona => _zona;
  bool get activo => _activo;
  bool get sinBrujula => _brujula.sinSensor;
  bool get barriendo => _barriendo;
  ResultadoBarrido? get ultimoBarrido => _ultimoBarrido;
  int get muestrasBarrido => _muestrasBarrido.length;

  /// Declinación aplicada (null: no se sabe y el rumbo es magnético).
  double? get declinacionGrados => _declinacionGrados;

  /// Lo que dice el sensor de su precisión ahora (15/30/45°), o null.
  double? get precisionBrujulaGrados => _brujula.ultima?.precisionGrados;

  /// Rumbo de la parte de arriba del móvil, verdadero si se sabe la
  /// declinación.
  double? get rumboActualGrados {
    final lectura = _brujula.ultima;
    if (lectura == null) return null;
    return normalizarRumbo(lectura.rumboMagneticoGrados + (_declinacionGrados ?? 0));
  }

  /// Cobertura del barrido en curso (o del último), en grados.
  double get coberturaBarridoGrados =>
      _barriendo ? analizarBarrido(_muestrasBarrido).coberturaGrados : (_ultimoBarrido?.coberturaGrados ?? 0);

  Future<void> cargarPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardada = preferencias.getDouble(_clavePreferenciaIncertidumbre);
      if (guardada != null && opcionesIncertidumbreGrados.contains(guardada)) {
        _incertidumbreGrados = guardada;
        _avisar();
      }
    } catch (_) {}
  }

  void cambiarIncertidumbre(double grados) {
    _incertidumbreGrados = grados;
    _avisar();
    unawaited(() async {
      try {
        final preferencias = await SharedPreferences.getInstance();
        await preferencias.setDouble(_clavePreferenciaIncertidumbre, grados);
      } catch (_) {}
    }());
  }

  /// Enciende la brújula (al abrir la tarjeta).
  void activar() {
    if (_activo) return;
    _activo = true;
    _brujula.empezar();
    _avisar();
  }

  Future<void> desactivar() async {
    _activo = false;
    _barriendo = false;
    await _brujula.detener();
    _avisar();
  }

  /// «Viene de aquí»: posición GPS + rumbo medio del último segundo. Con
  /// [rumboFijoGrados] (el del barrido) se usa ese rumbo, ya verdadero.
  Future<bool> tomarRumbo({double? rumboFijoGrados, bool orientativa = false}) async {
    if (_tomandoPosicion) return false;
    final rumboMagneticoMedio = _brujula.rumboMedio();
    if (rumboFijoGrados == null && rumboMagneticoMedio == null) {
      _ultimoError = ErrorTomaRumbo.sinBrujula;
      _avisar();
      return false;
    }
    final precisionBrujula = _brujula.precisionReciente();
    _tomandoPosicion = true;
    _ultimoError = null;
    _avisar();
    try {
      final permiso = await Geolocator.checkPermission();
      var concedido = permiso == LocationPermission.always || permiso == LocationPermission.whileInUse;
      if (!concedido) {
        final pedido = await Geolocator.requestPermission();
        concedido = pedido == LocationPermission.always || pedido == LocationPermission.whileInUse;
      }
      if (!concedido) {
        _ultimoError = ErrorTomaRumbo.sinPermisoUbicacion;
        return false;
      }
      Position? posicion;
      try {
        posicion = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (_) {
        posicion = await Geolocator.getLastKnownPosition();
      }
      if (posicion == null) {
        _ultimoError = ErrorTomaRumbo.sinPosicion;
        return false;
      }
      if (!_declinacionConsultada) {
        _declinacionConsultada = true;
        _declinacionGrados =
            await declinacionMagnetica(posicion.latitude, posicion.longitude, altitud: posicion.altitude);
      }
      final rumbo = rumboFijoGrados ?? normalizarRumbo(rumboMagneticoMedio! + (_declinacionGrados ?? 0));
      _tomas.add(TomaRumbo(
        latitud: posicion.latitude,
        longitud: posicion.longitude,
        precisionMetros: posicion.accuracy > 0 ? posicion.accuracy : null,
        rumboGrados: rumbo,
        incertidumbreGrados: orientativa
            ? (_incertidumbreGrados > incertidumbreBarridoGrados
                ? _incertidumbreGrados
                : incertidumbreBarridoGrados)
            : _incertidumbreGrados,
        precisionBrujulaGrados: rumboFijoGrados == null ? precisionBrujula : null,
        declinacionCorregida: _declinacionGrados != null,
        orientativa: orientativa,
        momento: DateTime.now(),
      ));
      _recalcular();
      return true;
    } catch (_) {
      _ultimoError = ErrorTomaRumbo.sinPosicion;
      return false;
    } finally {
      _tomandoPosicion = false;
      _avisar();
    }
  }

  void quitarToma(int indice) {
    if (indice < 0 || indice >= _tomas.length) return;
    _tomas.removeAt(indice);
    _recalcular();
    _avisar();
  }

  void borrarTomas() {
    _tomas.clear();
    _ultimoBarrido = null;
    _recalcular();
    _avisar();
  }

  void _recalcular() => _zona = estimarZona(_tomas);

  // ---------------------------------------------------------------- Barrido

  void empezarBarrido() {
    _brujula.empezar();
    _activo = true;
    _muestrasBarrido.clear();
    _ultimoBarrido = null;
    _barriendo = true;
    _avisar();
  }

  /// Nivel de la banda del canto de una trama de 0,1 s (lo llama la pantalla
  /// con cada trama del aviso de calidad).
  void alCerrarTramaAudio(double nivelBandaDecibelios) {
    if (!_barriendo) return;
    final rumbo = rumboActualGrados;
    if (rumbo == null) return;
    _muestrasBarrido.add(MuestraBarrido(rumbo, nivelBandaDecibelios));
    _avisarConPausa();
  }

  /// Termina el barrido y devuelve el análisis.
  ResultadoBarrido terminarBarrido() {
    _barriendo = false;
    final resultado = analizarBarrido(_muestrasBarrido);
    _ultimoBarrido = resultado;
    _muestrasBarrido.clear();
    _avisar();
    return resultado;
  }

  void cancelarBarrido() {
    _barriendo = false;
    _muestrasBarrido.clear();
    _avisar();
  }

  /// Para `Hallazgo.atributos['zona_animal']`, o null si no hay zona.
  Map<String, dynamic>? zonaParaHallazgo() {
    if (!_zona.hayZona) return null;
    return {
      ..._zona.aJson(_tomas),
      'rumbo_verdadero': _declinacionGrados != null,
      if (_declinacionGrados != null) 'declinacion': double.parse(_declinacionGrados!.toStringAsFixed(1)),
      'momento_ms': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _avisarConPausa() {
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoAviso).inMilliseconds < 150) return;
    _ultimoAviso = ahora;
    _avisar();
  }

  void _avisar() {
    if (!_liberado) notifyListeners();
  }

  @override
  void dispose() {
    _liberado = true;
    unawaited(_brujula.detener());
    super.dispose();
  }
}
