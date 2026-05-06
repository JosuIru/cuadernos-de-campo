import 'package:shared_preferences/shared_preferences.dart';

const String _claveApiKey = 'anthropic_api_key';
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
}
