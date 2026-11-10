import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sonido/especies_vigiladas.dart';

const _clavePreferenciaEspeciesVigiladas = 'nat.quien_canta.especies_vigiladas';

/// Especies vigiladas guardadas (nombres científicos del manifiesto).
Future<List<String>> leerEspeciesVigiladas() async {
  try {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getStringList(_clavePreferenciaEspeciesVigiladas) ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> guardarEspeciesVigiladas(List<String> etiquetas) async {
  try {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setStringList(
        _clavePreferenciaEspeciesVigiladas, etiquetas.take(maximoEspeciesVigiladas).toList());
  } catch (_) {}
}

/// Notificación local inmediata al oír una especie vigilada (con
/// vibración). Patrón de `nuevo_ser_avisos` del monorepo (canal propio,
/// icono de silueta, nada lanza), pero ese paquete solo programa avisos con
/// hora y aquí hace falta enseñarlo en el momento: por eso se usa
/// `flutter_local_notifications` directamente.
///
/// Solo se llama desde la pantalla de escucha abierta: no hay escucha en
/// segundo plano.
class AvisosEspeciesVigiladas {
  AvisosEspeciesVigiladas._();
  static final AvisosEspeciesVigiladas instancia = AvisosEspeciesVigiladas._();

  static const String idCanal = 'naturaleza_especies_vigiladas';
  static const String iconoAndroid = '@drawable/ic_aviso_sonido';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  Future<void> inicializar() async {
    if (_iniciado || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(iconoAndroid),
          linux: LinuxInitializationSettings(defaultActionName: 'Abrir'),
        ),
      );
      _iniciado = true;
    } catch (_) {
      // Sin notificaciones en la plataforma: la pantalla avisa igualmente.
    }
  }

  /// Android 13+: POST_NOTIFICATIONS. true si se puede avisar.
  Future<bool> pedirPermiso() async {
    await inicializar();
    if (!_iniciado) return false;
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vibra y enseña la notificación. Una por especie (la siguiente de la
  /// misma especie sustituye a la anterior).
  Future<void> avisar({required String etiqueta, required String titulo, required String cuerpo}) async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
    await inicializar();
    if (!_iniciado) return;
    try {
      await _plugin.show(
        id: _idDeEtiqueta(etiqueta),
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            idCanal,
            SoleraL10n.t('nat.vig_canal_nombre'),
            channelDescription: SoleraL10n.t('nat.vig_canal_descripcion'),
            importance: Importance.high,
            priority: Priority.high,
            icon: iconoAndroid,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
            category: AndroidNotificationCategory.reminder,
          ),
          linux: const LinuxNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  /// Id estable (FNV-1a de 31 bits), como `idDeClave` de nuevo_ser_avisos.
  static int _idDeEtiqueta(String etiqueta) {
    var hash = 0x811c9dc5;
    for (final unidad in 'vigilada.$etiqueta'.codeUnits) {
      hash ^= unidad;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
