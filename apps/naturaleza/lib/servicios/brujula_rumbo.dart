import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../sonido/triangulacion_rumbos.dart';

/// Brújula para «¿Dónde está?» (`flutter_compass`, que en Android usa el
/// vector de rotación). Da el rumbo **magnético** de la parte de arriba del
/// móvil; la declinación (diferencia con el norte verdadero) la calcula
/// Android con su modelo WMM (`GeomagneticField`) por un canal propio de la
/// app. Sin ese canal (Linux) el rumbo se queda magnético y se dice.

const MethodChannel _canalDeclinacion = MethodChannel('naturaleza/declinacion_magnetica');

/// Declinación magnética en grados (positiva al este), o null si la
/// plataforma no la sabe calcular.
Future<double?> declinacionMagnetica(double latitud, double longitud, {double altitud = 0}) async {
  try {
    final declinacion = await _canalDeclinacion.invokeMethod<double>('declinacion', {
      'latitud': latitud,
      'longitud': longitud,
      'altitud': altitud,
    });
    return declinacion;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// Lectura de la brújula en un momento.
class LecturaBrujula {
  final double rumboMagneticoGrados;

  /// Lo que dice Android de su precisión: 15°, 30° o 45° (o null).
  final double? precisionGrados;
  final DateTime momento;
  const LecturaBrujula(this.rumboMagneticoGrados, this.precisionGrados, this.momento);
}

/// Escucha la brújula mientras se usa y guarda el último segundo, para
/// promediar el rumbo al pulsar «Viene de aquí» (el pulso tiembla).
class LectorBrujula {
  final void Function(LecturaBrujula lectura)? alLeer;
  StreamSubscription<CompassEvent>? _suscripcion;
  final List<LecturaBrujula> _recientes = [];
  bool _sinSensor = false;
  String? _error;

  LectorBrujula({this.alLeer});

  bool get activo => _suscripcion != null;
  bool get sinSensor => _sinSensor;
  String? get error => _error;
  LecturaBrujula? get ultima => _recientes.isEmpty ? null : _recientes.last;

  void empezar() {
    if (_suscripcion != null) return;
    final eventos = FlutterCompass.events;
    if (eventos == null) {
      _sinSensor = true;
      return;
    }
    _suscripcion = eventos.listen(
      (evento) {
        final rumbo = evento.heading;
        if (rumbo == null) {
          _sinSensor = true;
          return;
        }
        _sinSensor = false;
        final lectura = LecturaBrujula(normalizarRumbo(rumbo), evento.accuracy, DateTime.now());
        _recientes.add(lectura);
        final limite = lectura.momento.subtract(const Duration(seconds: 2));
        _recientes.removeWhere((anterior) => anterior.momento.isBefore(limite));
        alLeer?.call(lectura);
      },
      onError: (Object error) {
        _error = error.toString();
        _sinSensor = true;
      },
    );
  }

  /// Media circular del rumbo magnético en la última [ventana], o null.
  double? rumboMedio({Duration ventana = const Duration(seconds: 1)}) {
    if (_recientes.isEmpty) return null;
    final desde = DateTime.now().subtract(ventana);
    final rumbos = [
      for (final lectura in _recientes)
        if (!lectura.momento.isBefore(desde)) lectura.rumboMagneticoGrados,
    ];
    return mediaCircularGrados(rumbos.isEmpty ? [_recientes.last.rumboMagneticoGrados] : rumbos);
  }

  /// La peor precisión que ha dado el sensor en la última [ventana].
  double? precisionReciente({Duration ventana = const Duration(seconds: 1)}) {
    final desde = DateTime.now().subtract(ventana);
    double? peor;
    for (final lectura in _recientes) {
      final precision = lectura.precisionGrados;
      if (lectura.momento.isBefore(desde) || precision == null) continue;
      if (peor == null || precision > peor) peor = precision;
    }
    return peor;
  }

  Future<void> detener() async {
    final suscripcion = _suscripcion;
    _suscripcion = null;
    _recientes.clear();
    await suscripcion?.cancel();
  }
}
