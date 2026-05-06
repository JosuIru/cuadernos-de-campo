import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> asegurarPermisoUbicacion() async {
  final servicioActivo = await Geolocator.isLocationServiceEnabled();
  if (!servicioActivo) return false;
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
    return false;
  }
  return true;
}

Future<bool> asegurarPermisoNotificaciones() async {
  final estado = await Permission.notification.status;
  if (estado.isGranted) return true;
  final nuevoEstado = await Permission.notification.request();
  return nuevoEstado.isGranted;
}
