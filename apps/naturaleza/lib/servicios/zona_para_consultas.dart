import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../fuentes_abiertas/ubicacion_aproximada.dart';
import '../utiles/permisos_gps.dart';

/// Zona aproximada de la persona para «Visto cerca de ti» y «Especies vistas
/// cerca». Solo se guarda la redondeada (0,1°) y solo en memoria, durante la
/// sesión: así, tras pedirla una vez, las demás fichas la usan sin volver a
/// preguntar. La posición exacta se descarta al momento.
class ZonaParaConsultas {
  ZonaParaConsultas._();

  static final ValueNotifier<UbicacionAproximada?> zonaDeLaSesion = ValueNotifier(null);

  /// Pide permiso si hace falta, toma la última posición conocida (o una
  /// nueva de baja precisión) y devuelve solo la zona redondeada.
  static Future<UbicacionAproximada?> pedir(BuildContext context) async {
    final hayPermiso = await asegurarPermisoUbicacion(context: context);
    if (!hayPermiso) return null;
    Position? posicion;
    try {
      posicion = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    try {
      posicion ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (_) {
      return null;
    }
    final zona = UbicacionAproximada.desde(posicion.latitude, posicion.longitude);
    zonaDeLaSesion.value = zona;
    return zona;
  }
}
