import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _claveApiKey = 'anthropic_api_key';
const String _claveApiKeyDeepseek = 'deepseek_api_key';
const String _claveModelo = 'modelo_claude';
const String modeloPorDefecto = modeloClaudePotente;

class ModeloDisponible {
  final String id;
  final String nombre;
  final String descripcion;
  final double precioOrientativoCentimosPorIdentificacion;
  const ModeloDisponible(this.id, this.nombre, this.descripcion, this.precioOrientativoCentimosPorIdentificacion);
}

// Precio orientativo por foto (USD → céntimos, redondeado hacia arriba):
// ~2.000 tokens de entrada (foto + prompt) y salida con razonamiento.
// Tarifas por millón de tokens entrada/salida: Opus 5.5 4/20, Sonnet 5.5
// 2/10, Haiku 5.5 0,10/0,50. Escalado desde las estimaciones de la familia
// 4.x y subido un poco porque los 5.5 razonan antes de responder.
const List<ModeloDisponible> modelosDisponibles = [
  ModeloDisponible(modeloClaudePotente, 'Claude Opus 5.5', 'Máxima precisión. Recomendado.', 4),
  ModeloDisponible(modeloClaudeEquilibrado, 'Claude Sonnet 5.5', 'Buen equilibrio precisión/coste.', 2),
  ModeloDisponible(modeloClaudeRapido, 'Claude Haiku 5.5', 'Mucho más barato. Aciertos algo menores.', 0.1),
];

class Configuracion {
  static Future<String> obtenerApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveApiKey) ?? '';
  }

  /// Modelo elegido, traducido al actual de su familia (quien tenga
  /// guardado `claude-opus-4-7` recibe Opus 5.5, etc.).
  static Future<String> obtenerModelo() async {
    final prefs = await SharedPreferences.getInstance();
    final modeloGuardado = prefs.getString(_claveModelo);
    if (modeloGuardado == null || modeloGuardado.trim().isEmpty) return modeloPorDefecto;
    return modeloClaudeActual(modeloGuardado);
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

  // ─── Onboarding (mini-tour de primer arranque) ─────────

  static const String _claveOnboardingVisto = 'ha_visto_onboarding_v1';

  static Future<bool> haVistoOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveOnboardingVisto) ?? false;
  }

  static Future<void> marcarOnboardingVisto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveOnboardingVisto, true);
  }
}
