import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado del intento de obtener permiso de ubicación.
enum ResultadoPermisoGps {
  concedido,
  servicioApagado,
  denegadoPuntual,
  denegadoPermanente,
}

/// Comprueba el servicio + permiso de ubicación. Si se devuelve
/// [ResultadoPermisoGps.denegadoPermanente] el usuario marcó "no
/// volver a preguntar" y la única salida es abrir Ajustes del SO.
Future<ResultadoPermisoGps> comprobarPermisoUbicacion() async {
  final servicioActivo = await Geolocator.isLocationServiceEnabled();
  if (!servicioActivo) return ResultadoPermisoGps.servicioApagado;
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.deniedForever) {
    return ResultadoPermisoGps.denegadoPermanente;
  }
  if (permiso == LocationPermission.denied) {
    return ResultadoPermisoGps.denegadoPuntual;
  }
  return ResultadoPermisoGps.concedido;
}

/// Wrapper compatible con call-sites previos. Devuelve true si la app
/// tiene permiso útil ahora mismo. Si llega [context], muestra el
/// diálogo amable que abre Ajustes del SO cuando el usuario denegó
/// permanentemente — sin contexto se mantiene el comportamiento legacy
/// (devuelve false silenciosamente).
Future<bool> asegurarPermisoUbicacion({BuildContext? context}) async {
  final resultado = await comprobarPermisoUbicacion();
  if (resultado == ResultadoPermisoGps.concedido) return true;
  if (context != null && context.mounted) {
    if (resultado == ResultadoPermisoGps.denegadoPermanente) {
      await _mostrarDialogoAjustes(
        context,
        titulo: SoleraL10n.t('fos.mapa_permiso_bloqueado'),
        mensaje: SoleraL10n.t('fos.mapa_permiso_bloqueado_texto'),
      );
    } else if (resultado == ResultadoPermisoGps.servicioApagado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SoleraL10n.t('fos.mapa_activa_gps'))),
      );
    } else if (resultado == ResultadoPermisoGps.denegadoPuntual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SoleraL10n.t('fos.mapa_necesito_permiso'))),
      );
    }
  }
  return false;
}

Future<void> _mostrarDialogoAjustes(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(SoleraL10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await openAppSettings();
          },
          child: Text(SoleraL10n.t('fos.mapa_abrir_ajustes')),
        ),
      ],
    ),
  );
}

Future<bool> asegurarPermisoNotificaciones() async {
  final estado = await Permission.notification.status;
  if (estado.isGranted) return true;
  final nuevoEstado = await Permission.notification.request();
  return nuevoEstado.isGranted;
}
