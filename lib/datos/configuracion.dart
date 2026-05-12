import 'package:shared_preferences/shared_preferences.dart';

const String _claveApiKey = 'anthropic_api_key';
const String _claveApiKeyDeepseek = 'deepseek_api_key';
const String _claveModelo = 'modelo_claude';
const String modeloPorDefecto = 'claude-opus-4-7';

class ModeloDisponible {
  final String id;
  final String nombre;
  final String descripcion;
  final double precioOrientativoCentimosPorIdentificacion;
  const ModeloDisponible(this.id, this.nombre, this.descripcion, this.precioOrientativoCentimosPorIdentificacion);
}

const List<ModeloDisponible> modelosDisponibles = [
  ModeloDisponible('claude-opus-4-7', 'Claude Opus 4.7', 'Máxima precisión. Recomendado.', 1.5),
  ModeloDisponible('claude-sonnet-4-6', 'Claude Sonnet 4.6', 'Buen equilibrio precisión/coste.', 0.5),
  ModeloDisponible('claude-haiku-4-5', 'Claude Haiku 4.5', 'Más barato. Aciertos algo menores.', 0.2),
];

class Configuracion {
  static Future<String> obtenerApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveApiKey) ?? '';
  }

  static Future<String> obtenerModelo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveModelo) ?? modeloPorDefecto;
  }

  static Future<void> guardarApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveApiKey, apiKey);
  }

  static Future<void> guardarModelo(String modelo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveModelo, modelo);
  }

  static Future<bool> tieneApiKey() async {
    final apiKey = await obtenerApiKey();
    return apiKey.trim().isNotEmpty;
  }

  static Future<String> obtenerApiKeyDeepseek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveApiKeyDeepseek) ?? '';
  }

  static Future<void> guardarApiKeyDeepseek(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveApiKeyDeepseek, apiKey.trim());
  }

  // ─── Perfil del descubridor ─────────────────────────────

  static Future<String> obtenerNombreDescubridor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('descubridor_nombre') ?? '';
  }

  static Future<String> obtenerEmailDescubridor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('descubridor_email') ?? '';
  }

  static Future<String> obtenerOrganizacionDescubridor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('descubridor_org') ?? '';
  }

  static Future<void> guardarNombreDescubridor(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('descubridor_nombre', nombre.trim());
  }

  static Future<void> guardarEmailDescubridor(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('descubridor_email', email.trim());
  }

  static Future<void> guardarOrganizacionDescubridor(String org) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('descubridor_org', org.trim());
  }

  static Future<bool> perfilDescubridorCompleto() async {
    final nombre = await obtenerNombreDescubridor();
    return nombre.isNotEmpty;
  }
}
