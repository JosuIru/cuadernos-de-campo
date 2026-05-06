import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseInaturalist = 'https://api.inaturalist.org/v1';
const _cabecerasInaturalist = {
  'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
  'Accept': 'application/json',
};

class ResultadoTaxonInaturalist {
  final int id;
  final String nombreCientifico;
  final String? nombreComun;
  final String? rangoTaxonomico;
  final String? urlFoto;
  final String? reino;
  final List<String> ancestros;

  ResultadoTaxonInaturalist({
    required this.id,
    required this.nombreCientifico,
    this.nombreComun,
    this.rangoTaxonomico,
    this.urlFoto,
    this.reino,
    this.ancestros = const [],
  });

  /// Categoría aproximada del cuaderno: 'planta' | 'insecto' | 'animal' | null.
  String? get categoriaInferida {
    final r = reino;
    if (r == null) return null;
    if (r == 'Plantae' || r == 'Fungi') return 'planta';
    if (r == 'Animalia') {
      // Detectar artrópodos por la cadena de ancestros si está disponible.
      const filosArtropodos = {'Arthropoda'};
      for (final ancestro in ancestros) {
        if (filosArtropodos.contains(ancestro)) return 'insecto';
      }
      return 'animal';
    }
    return null;
  }
}

/// Busca taxones por nombre común o científico.
///
/// [rango] opcional: 'species', 'genus', 'family', etc.
/// [locale] el idioma para nombres comunes (ej. 'es').
Future<List<ResultadoTaxonInaturalist>> buscarTaxones(
  String consulta, {
  String? rango,
  int limite = 10,
  String locale = 'es',
}) async {
  final consultaLimpia = consulta.trim();
  if (consultaLimpia.isEmpty) return const [];

  final parametros = <String, String>{
    'q': consultaLimpia,
    'per_page': limite.clamp(1, 30).toString(),
    'locale': locale,
  };
  if (rango != null && rango.isNotEmpty) {
    parametros['rank'] = rango;
  }

  final uri = Uri.parse('$_baseInaturalist/taxa').replace(queryParameters: parametros);
  final respuesta = await http.get(uri, headers: _cabecerasInaturalist);
  if (respuesta.statusCode != 200) {
    throw Exception('iNaturalist devolvió ${respuesta.statusCode}');
  }
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];

  return resultados.cast<Map<String, dynamic>>().map((mapa) {
    final fotoDefecto = mapa['default_photo'] as Map<String, dynamic>?;
    final ancestros = (mapa['ancestors'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((a) => (a['name'] as String?) ?? '')
            .where((nombre) => nombre.isNotEmpty)
            .toList() ??
        const <String>[];
    return ResultadoTaxonInaturalist(
      id: (mapa['id'] as num).toInt(),
      nombreCientifico: (mapa['name'] as String?) ?? '',
      nombreComun: mapa['preferred_common_name'] as String?,
      rangoTaxonomico: mapa['rank'] as String?,
      urlFoto: fotoDefecto?['medium_url'] as String? ?? fotoDefecto?['square_url'] as String?,
      reino: _inferirReinoDesdeAncestros(mapa) ?? mapa['iconic_taxon_name'] as String?,
      ancestros: ancestros,
    );
  }).toList();
}

String? _inferirReinoDesdeAncestros(Map<String, dynamic> mapa) {
  final iconico = mapa['iconic_taxon_name'] as String?;
  if (iconico == null) return null;
  return switch (iconico) {
    'Plantae' || 'Fungi' => 'Plantae',
    'Animalia' || 'Mammalia' || 'Aves' || 'Reptilia' || 'Amphibia' || 'Actinopterygii' || 'Mollusca' => 'Animalia',
    'Insecta' || 'Arachnida' => 'Animalia',
    _ => iconico,
  };
}

/// Caché en memoria para miniaturas por nombre científico.
final Map<String, Future<String?>> _cacheMiniaturasPorNombre = {};

/// Devuelve la URL de la miniatura más representativa para [nombreCientifico].
/// Cachea los resultados (incluyendo nulls) para no martillear iNaturalist.
Future<String?> miniaturaPorNombreCientifico(String nombreCientifico) {
  final clave = nombreCientifico.trim().toLowerCase();
  if (clave.isEmpty) return Future.value(null);
  return _cacheMiniaturasPorNombre.putIfAbsent(clave, () async {
    try {
      final resultados = await buscarTaxones(nombreCientifico, limite: 1);
      if (resultados.isEmpty) return null;
      return resultados.first.urlFoto;
    } catch (_) {
      return null;
    }
  });
}

/// Detalle de un taxon por id (devuelve la cadena ancestral completa).
Future<ResultadoTaxonInaturalist?> obtenerTaxon(int id, {String locale = 'es'}) async {
  final uri = Uri.parse('$_baseInaturalist/taxa/$id').replace(queryParameters: {'locale': locale});
  final respuesta = await http.get(uri, headers: _cabecerasInaturalist);
  if (respuesta.statusCode != 200) return null;
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];
  if (resultados.isEmpty) return null;
  final mapa = resultados.first as Map<String, dynamic>;
  final ancestros = (mapa['ancestors'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map((a) => (a['name'] as String?) ?? '')
          .where((nombre) => nombre.isNotEmpty)
          .toList() ??
      const <String>[];
  final fotoDefecto = mapa['default_photo'] as Map<String, dynamic>?;
  return ResultadoTaxonInaturalist(
    id: (mapa['id'] as num).toInt(),
    nombreCientifico: (mapa['name'] as String?) ?? '',
    nombreComun: mapa['preferred_common_name'] as String?,
    rangoTaxonomico: mapa['rank'] as String?,
    urlFoto: fotoDefecto?['medium_url'] as String?,
    reino: _inferirReinoDesdeAncestros(mapa),
    ancestros: ancestros,
  );
}
