import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Token UUID v4 anónimo y estable por instalación de la app. Se genera
/// la primera vez que se consulta y se persiste en SharedPreferences.
///
/// NO identifica a la persona — solo al dispositivo, y solo para
/// rate-limit en el backend (cantidad de aportaciones diarias por
/// dispositivo, antispam básico).
///
/// El token vive el ciclo de vida del install. Si el usuario reinstala
/// la app, recibe un token nuevo y el rate-limit se reinicia. Es
/// asumible: si quiere abusar, le basta con reinstalar; pero entonces
/// pierde cualquier referencia a sus aportaciones previas vía email.
class IdentidadDispositivo {
  static const String _claveTokenDispositivo = 'token_dispositivo_comunidad_v1';

  /// Devuelve el token, generándolo en el primer acceso.
  static Future<String> obtenerToken() async {
    final preferencias = await SharedPreferences.getInstance();
    var token = preferencias.getString(_claveTokenDispositivo);
    if (token == null || token.isEmpty) {
      token = _generarUuidV4();
      await preferencias.setString(_claveTokenDispositivo, token);
    }
    return token;
  }

  /// Genera un UUID v4 sin dependencia externa.
  static String _generarUuidV4() {
    final aleatorio = Random.secure();
    final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
    // Versión 4 (bits 12-15 del time_hi_and_version).
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variante RFC 4122 (bits 6-7 del clock_seq_hi_and_reserved).
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
