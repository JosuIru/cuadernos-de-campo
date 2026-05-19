import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cliente de Pl@ntNet API v2.
///
/// Pl@ntNet es un servicio gratuito de identificación de plantas por
/// imagen mantenido por consorcio académico (INRIA, INRA, IRD, CIRAD).
/// Devuelve un ranking de especies candidatas con un score de
/// confianza basado en redes neuronales entrenadas sobre el corpus
/// colaborativo de Pl@ntNet.
///
/// Plan gratuito: 500 identificaciones por día y por API key.
/// Registro de API key: https://my.plantnet.org/
///
/// La frontera de privacidad de la app se respeta: la foto **sólo**
/// cruza red si el usuario pulsa explícitamente el botón
/// "identificar con Pl@ntNet". No hay envío automático ni en
/// background.
const _baseUrlPlantNet = 'https://my-api.plantnet.org/v2/identify';

/// Órganos de la planta visibles en la foto. Pl@ntNet usa esta
/// pista para focalizar la identificación. `auto` (omitir el campo)
/// también funciona pero da peor precisión.
enum OrganoPlantNet {
  hoja('leaf'),
  flor('flower'),
  fruto('fruit'),
  corteza('bark'),
  habito('habit'),
  otro('other');

  final String codigoApi;
  const OrganoPlantNet(this.codigoApi);
}

class CandidatoPlantNet {
  final double score;
  final String nombreCientifico;
  final String? autor;
  final List<String> nombresComunes;
  final String? genero;
  final String? familia;

  CandidatoPlantNet({
    required this.score,
    required this.nombreCientifico,
    required this.autor,
    required this.nombresComunes,
    required this.genero,
    required this.familia,
  });

  String? get nombreComunPreferido =>
      nombresComunes.isEmpty ? null : nombresComunes.first;
}

class ResultadoPlantNet {
  final List<CandidatoPlantNet> candidatos;
  final int? quedanHoy;
  ResultadoPlantNet({required this.candidatos, required this.quedanHoy});
}

/// Lanzado cuando Pl@ntNet rechaza por API key inválida o expirada.
class PlantNetClaveInvalida implements Exception {
  final String mensaje;
  PlantNetClaveInvalida(this.mensaje);
  @override
  String toString() => 'PlantNetClaveInvalida: $mensaje';
}

/// Lanzado cuando Pl@ntNet rechaza por cuota agotada (HTTP 429).
class PlantNetCuotaAgotada implements Exception {
  final String mensaje;
  PlantNetCuotaAgotada(this.mensaje);
  @override
  String toString() => 'PlantNetCuotaAgotada: $mensaje';
}

/// Identifica la planta de [rutaFotoLocal] contra el proyecto
/// [proyecto] (default `all` — todo el catálogo mundial; para
/// Iberia rinde mejor `weurope` o `the-plant-list`).
Future<ResultadoPlantNet> identificarPlantaConPlantNet({
  required String rutaFotoLocal,
  required String apiKey,
  OrganoPlantNet organo = OrganoPlantNet.hoja,
  String proyecto = 'all',
  int candidatosMaximos = 5,
}) async {
  if (apiKey.trim().isEmpty) {
    throw PlantNetClaveInvalida('Falta la clave API de Pl@ntNet.');
  }
  final fichero = File(rutaFotoLocal);
  if (!await fichero.exists()) {
    throw Exception('La foto no existe en disco: $rutaFotoLocal');
  }

  final uri = Uri.parse('$_baseUrlPlantNet/$proyecto').replace(
    queryParameters: {
      'api-key': apiKey,
      'nb-results': candidatosMaximos.toString(),
      'lang': 'es',
    },
  );

  final peticion = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('images', rutaFotoLocal))
    ..fields['organs'] = organo.codigoApi;

  final respuestaStream = await peticion.send();
  final respuesta = await http.Response.fromStream(respuestaStream);

  if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
    throw PlantNetClaveInvalida(
      'Pl@ntNet rechazó la clave (HTTP ${respuesta.statusCode}). '
      'Comprueba la clave en Ajustes.',
    );
  }
  if (respuesta.statusCode == 429) {
    throw PlantNetCuotaAgotada(
      'Pl@ntNet devolvió cuota agotada para hoy (HTTP 429).',
    );
  }
  if (respuesta.statusCode != 200) {
    throw Exception(
      'Pl@ntNet devolvió ${respuesta.statusCode}: '
      '${respuesta.body.substring(0, respuesta.body.length.clamp(0, 200))}',
    );
  }

  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final results = (cuerpo['results'] as List?) ?? const [];
  final candidatos = results.cast<Map<String, dynamic>>().map((mapa) {
    final score = (mapa['score'] as num?)?.toDouble() ?? 0.0;
    final species = mapa['species'] as Map<String, dynamic>?;
    final nombreCientifico = species?['scientificNameWithoutAuthor'] as String? ?? '';
    final autor = species?['scientificNameAuthorship'] as String?;
    final nombresComunes = ((species?['commonNames'] as List?) ?? const [])
        .cast<String>()
        .where((nombre) => nombre.trim().isNotEmpty)
        .toList();
    final genero = (species?['genus'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor']
        as String?;
    final familia = (species?['family'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor']
        as String?;
    return CandidatoPlantNet(
      score: score,
      nombreCientifico: nombreCientifico,
      autor: autor,
      nombresComunes: nombresComunes,
      genero: genero,
      familia: familia,
    );
  }).where((c) => c.nombreCientifico.isNotEmpty).toList();

  final restos = (cuerpo['remainingIdentificationRequests'] as num?)?.toInt();

  return ResultadoPlantNet(candidatos: candidatos, quedanHoy: restos);
}
