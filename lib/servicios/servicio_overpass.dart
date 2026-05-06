import 'dart:convert';
import 'package:http/http.dart' as http;

const _endpointsOverpass = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.osm.ch/api/interpreter',
];

const _cabecerasOverpass = {
  'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
  'Accept': 'application/json',
};

enum TipoLugarInteres {
  mirador,
  miradorAves,
  reservaNatural,
  cueva,
  humedal,
  arbolSingular,
  refugio,
  manantial,
  centroVisitantes,
}

extension TipoLugarInteresEtiqueta on TipoLugarInteres {
  String get etiqueta => switch (this) {
        TipoLugarInteres.mirador => 'Miradores',
        TipoLugarInteres.miradorAves => 'Miradores de aves',
        TipoLugarInteres.reservaNatural => 'Reservas naturales',
        TipoLugarInteres.cueva => 'Cuevas',
        TipoLugarInteres.humedal => 'Charcas y humedales',
        TipoLugarInteres.arbolSingular => 'Árboles singulares',
        TipoLugarInteres.refugio => 'Refugios',
        TipoLugarInteres.manantial => 'Manantiales y fuentes',
        TipoLugarInteres.centroVisitantes => 'Centros de visitantes',
      };

  /// Filtros Overpass que producen este tipo (sin envoltorio de bbox).
  List<String> get filtrosOverpass => switch (this) {
        TipoLugarInteres.mirador => [
            'node["tourism"="viewpoint"]',
            'way["tourism"="viewpoint"]',
          ],
        TipoLugarInteres.miradorAves => [
            'node["leisure"="bird_hide"]',
            'way["leisure"="bird_hide"]',
            'node["tourism"="viewpoint"]["wildlife"="birds"]',
          ],
        TipoLugarInteres.reservaNatural => [
            'way["leisure"="nature_reserve"]',
            'relation["leisure"="nature_reserve"]',
            'way["boundary"="protected_area"]',
            'relation["boundary"="protected_area"]',
          ],
        TipoLugarInteres.cueva => [
            'node["natural"="cave_entrance"]',
          ],
        TipoLugarInteres.humedal => [
            'way["natural"="wetland"]',
            'relation["natural"="wetland"]',
            'node["natural"="water"]["water"~"pond|lake"]',
            'way["natural"="water"]["water"~"pond|lake"]',
          ],
        TipoLugarInteres.arbolSingular => [
            'node["natural"="tree"]["denotation"="natural_monument"]',
            'node["natural"="tree"]["protection_title"]',
          ],
        TipoLugarInteres.refugio => [
            'node["tourism"="alpine_hut"]',
            'node["tourism"="wilderness_hut"]',
            'node["amenity"="shelter"]',
          ],
        TipoLugarInteres.manantial => [
            'node["natural"="spring"]',
            'node["amenity"="drinking_water"]',
          ],
        TipoLugarInteres.centroVisitantes => [
            'node["tourism"="information"]["information"~"visitor_centre|nature_centre"]',
          ],
      };
}

class LugarInteres {
  final String id;
  final TipoLugarInteres tipo;
  final String? nombre;
  final double latitud;
  final double longitud;
  final Map<String, String> tags;

  LugarInteres({
    required this.id,
    required this.tipo,
    this.nombre,
    required this.latitud,
    required this.longitud,
    this.tags = const {},
  });

  String get tituloMostrado {
    if (nombre != null && nombre!.isNotEmpty) return nombre!;
    return tipo.etiqueta;
  }
}

/// Consulta lugares de interés en el bbox dado para los [tipos] pedidos.
/// Limita el resultado a `limite` elementos por tipo para no saturar.
Future<List<LugarInteres>> lugaresInteresEnBbox({
  required double sur,
  required double norte,
  required double oeste,
  required double este,
  required Set<TipoLugarInteres> tipos,
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (tipos.isEmpty) return const [];

  final partes = <String>[];
  for (final tipo in tipos) {
    for (final filtro in tipo.filtrosOverpass) {
      partes.add('$filtro($sur,$oeste,$norte,$este);');
    }
  }
  final consulta = '''
    [out:json][timeout:25];
    (
      ${partes.join('\n      ')}
    );
    out center 200;
  ''';

  http.Response? respuestaUtil;
  Exception? ultimoError;
  for (final endpoint in _endpointsOverpass) {
    try {
      final respuesta = await http
          .post(
            Uri.parse(endpoint),
            headers: _cabecerasOverpass,
            body: 'data=${Uri.encodeQueryComponent(consulta)}',
          )
          .timeout(timeout);
      if (respuesta.statusCode == 200) {
        respuestaUtil = respuesta;
        break;
      }
      ultimoError = Exception('Overpass devolvió ${respuesta.statusCode} en $endpoint');
    } catch (e) {
      ultimoError = e is Exception ? e : Exception(e.toString());
    }
  }
  if (respuestaUtil == null) {
    throw ultimoError ?? Exception('Overpass no respondió en ningún endpoint');
  }

  final cuerpo = jsonDecode(utf8.decode(respuestaUtil.bodyBytes)) as Map<String, dynamic>;
  final elementos = (cuerpo['elements'] as List?) ?? const [];

  final lugares = <LugarInteres>[];
  for (final elemento in elementos.cast<Map<String, dynamic>>()) {
    final tags = (elemento['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tagsString = tags.map((clave, valor) => MapEntry(clave, valor.toString()));
    double? lat;
    double? lon;
    if (elemento.containsKey('lat')) {
      lat = (elemento['lat'] as num?)?.toDouble();
      lon = (elemento['lon'] as num?)?.toDouble();
    } else if (elemento['center'] != null) {
      final centro = elemento['center'] as Map<String, dynamic>;
      lat = (centro['lat'] as num?)?.toDouble();
      lon = (centro['lon'] as num?)?.toDouble();
    }
    if (lat == null || lon == null) continue;
    final tipo = _inferirTipo(tagsString);
    if (tipo == null) continue;
    lugares.add(
      LugarInteres(
        id: '${elemento['type']}/${elemento['id']}',
        tipo: tipo,
        nombre: tagsString['name'],
        latitud: lat,
        longitud: lon,
        tags: tagsString,
      ),
    );
  }
  return lugares;
}

TipoLugarInteres? _inferirTipo(Map<String, String> tags) {
  if (tags['leisure'] == 'bird_hide') return TipoLugarInteres.miradorAves;
  if (tags['tourism'] == 'viewpoint' && tags['wildlife'] == 'birds') return TipoLugarInteres.miradorAves;
  if (tags['tourism'] == 'viewpoint') return TipoLugarInteres.mirador;
  if (tags['leisure'] == 'nature_reserve' || tags['boundary'] == 'protected_area') {
    return TipoLugarInteres.reservaNatural;
  }
  if (tags['natural'] == 'cave_entrance') return TipoLugarInteres.cueva;
  if (tags['natural'] == 'wetland') return TipoLugarInteres.humedal;
  if (tags['natural'] == 'water' && (tags['water'] == 'pond' || tags['water'] == 'lake')) {
    return TipoLugarInteres.humedal;
  }
  if (tags['natural'] == 'tree' &&
      (tags['denotation'] == 'natural_monument' || tags['protection_title'] != null)) {
    return TipoLugarInteres.arbolSingular;
  }
  if (tags['tourism'] == 'alpine_hut' || tags['tourism'] == 'wilderness_hut' || tags['amenity'] == 'shelter') {
    return TipoLugarInteres.refugio;
  }
  if (tags['natural'] == 'spring' || tags['amenity'] == 'drinking_water') return TipoLugarInteres.manantial;
  if (tags['tourism'] == 'information' &&
      (tags['information'] == 'visitor_centre' || tags['information'] == 'nature_centre')) {
    return TipoLugarInteres.centroVisitantes;
  }
  return null;
}
