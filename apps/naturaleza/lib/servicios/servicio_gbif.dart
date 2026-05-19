import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseGbif = 'https://api.gbif.org/v1';
const _cabecerasGbif = {
  'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
  'Accept': 'application/json',
};

class CoincidenciaTaxonGbif {
  final int? claveUso;
  final String? nombreCientifico;
  final String? rangoTaxonomico;
  final String? reino;
  final String? filo;
  final String? clase;
  final String? orden;
  final String? familia;
  final String? genero;

  CoincidenciaTaxonGbif({
    this.claveUso,
    this.nombreCientifico,
    this.rangoTaxonomico,
    this.reino,
    this.filo,
    this.clase,
    this.orden,
    this.familia,
    this.genero,
  });

  String get taxonomiaCompacta {
    final partes = [reino, filo, clase, orden, familia, genero].where((p) => p != null && p.isNotEmpty).toList();
    return partes.join(' › ');
  }
}

Future<CoincidenciaTaxonGbif?> emparejarNombreCientifico(String nombreCientifico) async {
  final uri = Uri.parse('$_baseGbif/species/match').replace(queryParameters: {'name': nombreCientifico});
  final respuesta = await http.get(uri, headers: _cabecerasGbif);
  if (respuesta.statusCode != 200) return null;
  final mapa = jsonDecode(respuesta.body) as Map<String, dynamic>;
  if (mapa['matchType'] == 'NONE') return null;
  return CoincidenciaTaxonGbif(
    claveUso: mapa['usageKey'] as int?,
    nombreCientifico: mapa['scientificName'] as String?,
    rangoTaxonomico: mapa['rank'] as String?,
    reino: mapa['kingdom'] as String?,
    filo: mapa['phylum'] as String?,
    clase: mapa['class'] as String?,
    orden: mapa['order'] as String?,
    familia: mapa['family'] as String?,
    genero: mapa['genus'] as String?,
  );
}

class OcurrenciaGbif {
  final int? claveOcurrencia;
  final String? nombreCientifico;
  final String? nombreAceptado;
  final String? reino;
  final String? familia;
  final double? latitud;
  final double? longitud;
  final String? fechaEvento;
  final String? pais;
  final String? localidad;
  final String? baseRegistro;
  final int? claveTaxon;

  OcurrenciaGbif({
    this.claveOcurrencia,
    this.nombreCientifico,
    this.nombreAceptado,
    this.reino,
    this.familia,
    this.latitud,
    this.longitud,
    this.fechaEvento,
    this.pais,
    this.localidad,
    this.baseRegistro,
    this.claveTaxon,
  });
}

/// Devuelve ocurrencias de GBIF dentro de un bbox (cuadrado lat/lon).
Future<List<OcurrenciaGbif>> ocurrenciasEnBbox({
  required double latMin,
  required double latMax,
  required double lonMin,
  required double lonMax,
  int? claveTaxon,
  int limite = 100,
}) async {
  final parametros = <String, String>{
    'decimalLatitude': '$latMin,$latMax',
    'decimalLongitude': '$lonMin,$lonMax',
    'hasCoordinate': 'true',
    'hasGeospatialIssue': 'false',
    'limit': limite.clamp(1, 300).toString(),
  };
  if (claveTaxon != null) {
    parametros['taxonKey'] = claveTaxon.toString();
  }

  final uri = Uri.parse('$_baseGbif/occurrence/search').replace(queryParameters: parametros);
  final respuesta = await http.get(uri, headers: _cabecerasGbif);
  if (respuesta.statusCode != 200) {
    throw Exception('GBIF devolvió ${respuesta.statusCode}');
  }
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];
  return resultados.cast<Map<String, dynamic>>().map((mapa) {
    return OcurrenciaGbif(
      claveOcurrencia: (mapa['key'] as num?)?.toInt(),
      nombreCientifico: mapa['scientificName'] as String?,
      nombreAceptado: mapa['acceptedScientificName'] as String?,
      reino: mapa['kingdom'] as String?,
      familia: mapa['family'] as String?,
      latitud: (mapa['decimalLatitude'] as num?)?.toDouble(),
      longitud: (mapa['decimalLongitude'] as num?)?.toDouble(),
      fechaEvento: mapa['eventDate'] as String?,
      pais: mapa['country'] as String?,
      localidad: mapa['locality'] as String?,
      baseRegistro: mapa['basisOfRecord'] as String?,
      claveTaxon: (mapa['taxonKey'] as num?)?.toInt(),
    );
  }).toList();
}

/// Devuelve ocurrencias de GBIF dentro de un cuadrado aproximado alrededor del punto.
///
/// GBIF no tiene un parámetro de radio directo, así que se usa un bounding box
/// derivado del [radioKm]. Para filtrar por especie, pasa [claveTaxon] con el
/// usageKey obtenido de [emparejarNombreCientifico].
Future<List<OcurrenciaGbif>> ocurrenciasCercanas({
  required double latitud,
  required double longitud,
  double radioKm = 5,
  int? claveTaxon,
  int limite = 50,
}) async {
  final radioGrados = radioKm / 111.0;
  final latMin = (latitud - radioGrados).clamp(-90.0, 90.0);
  final latMax = (latitud + radioGrados).clamp(-90.0, 90.0);
  final lonMin = longitud - radioGrados;
  final lonMax = longitud + radioGrados;

  final parametros = <String, String>{
    'decimalLatitude': '$latMin,$latMax',
    'decimalLongitude': '$lonMin,$lonMax',
    'hasCoordinate': 'true',
    'hasGeospatialIssue': 'false',
    'limit': limite.clamp(1, 300).toString(),
  };
  if (claveTaxon != null) {
    parametros['taxonKey'] = claveTaxon.toString();
  }

  final uri = Uri.parse('$_baseGbif/occurrence/search').replace(queryParameters: parametros);
  final respuesta = await http.get(uri, headers: _cabecerasGbif);
  if (respuesta.statusCode != 200) {
    throw Exception('GBIF devolvió ${respuesta.statusCode}');
  }
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];
  return resultados.cast<Map<String, dynamic>>().map((mapa) {
    return OcurrenciaGbif(
      claveOcurrencia: (mapa['key'] as num?)?.toInt(),
      nombreCientifico: mapa['scientificName'] as String?,
      nombreAceptado: mapa['acceptedScientificName'] as String?,
      reino: mapa['kingdom'] as String?,
      familia: mapa['family'] as String?,
      latitud: (mapa['decimalLatitude'] as num?)?.toDouble(),
      longitud: (mapa['decimalLongitude'] as num?)?.toDouble(),
      fechaEvento: mapa['eventDate'] as String?,
      pais: mapa['country'] as String?,
      localidad: mapa['locality'] as String?,
      baseRegistro: mapa['basisOfRecord'] as String?,
      claveTaxon: (mapa['taxonKey'] as num?)?.toInt(),
    );
  }).toList();
}
