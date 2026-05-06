import 'servicio_cuevas.dart' show LimitesGeograficos;
import 'servicio_overpass.dart';

class MonumentoArqueologico {
  final String id;
  final double latitud;
  final double longitud;
  final String nombre;
  final String tipoOriginal;
  final String tipoLegible;
  final String emoji;
  final String? descripcion;
  final String? historico;
  final String enlaceOSM;
  MonumentoArqueologico({
    required this.id,
    required this.latitud,
    required this.longitud,
    required this.nombre,
    required this.tipoOriginal,
    required this.tipoLegible,
    required this.emoji,
    this.descripcion,
    this.historico,
    required this.enlaceOSM,
  });
}

const Map<String, ({String legible, String emoji})> _categorias = {
  'megalith': (legible: 'Megalito (dolmen / cromlech / harrespil)', emoji: '🗿'),
  'dolmen': (legible: 'Dolmen', emoji: '🗿'),
  'tumulus': (legible: 'Túmulo', emoji: '⛰️'),
  'hut_circle': (legible: 'Fondo de cabaña', emoji: '🏚️'),
  'fortification': (legible: 'Fortificación / castro', emoji: '🏰'),
  'castle': (legible: 'Castillo', emoji: '🏰'),
  'settlement': (legible: 'Poblado / asentamiento', emoji: '🏘️'),
  'menhir': (legible: 'Menhir', emoji: '🪨'),
  'stone': (legible: 'Piedra antigua', emoji: '🪨'),
  'stone_circle': (legible: 'Círculo de piedras', emoji: '⭕'),
  'tomb': (legible: 'Tumba', emoji: '⚰️'),
  'ruins': (legible: 'Ruinas', emoji: '🏛️'),
  'monument': (legible: 'Monumento', emoji: '🗽'),
  'memorial': (legible: 'Memorial', emoji: '🗽'),
  'wayside_cross': (legible: 'Crucero / cruz de caminos', emoji: '✝️'),
  'archaeological_site': (legible: 'Yacimiento arqueológico', emoji: '🗿'),
};

({String legible, String emoji}) _categorizar(Map<String, dynamic> tags) {
  final tipoYacimiento = tags['archaeological_site']?.toString() ?? '';
  final tipoTumba = tags['tomb']?.toString() ?? '';
  final tipoSitio = tags['site_type']?.toString() ?? '';
  final hist = tags['historic']?.toString() ?? '';
  if (_categorias.containsKey(tipoYacimiento)) return _categorias[tipoYacimiento]!;
  if (_categorias.containsKey(tipoTumba)) return _categorias[tipoTumba]!;
  if (_categorias.containsKey(tipoSitio)) return _categorias[tipoSitio]!;
  if (_categorias.containsKey(hist)) return _categorias[hist]!;
  return (legible: 'Yacimiento arqueológico', emoji: '🗿');
}

({double? lat, double? lon}) _extraerCoordenadas(Map<String, dynamic> elemento) {
  if (elemento['lat'] != null && elemento['lon'] != null) {
    return (lat: (elemento['lat'] as num).toDouble(), lon: (elemento['lon'] as num).toDouble());
  }
  final centro = elemento['center'];
  if (centro is Map && centro['lat'] != null && centro['lon'] != null) {
    return (lat: (centro['lat'] as num).toDouble(), lon: (centro['lon'] as num).toDouble());
  }
  return (lat: null, lon: null);
}

Future<List<MonumentoArqueologico>> buscarMonumentosArqueologicos(LimitesGeograficos limites) async {
  final bbox = '${limites.sur},${limites.oeste},${limites.norte},${limites.este}';
  final consulta = '''
[out:json][timeout:60];
(
  nwr["historic"="archaeological_site"]($bbox);
  nwr["historic"="megalith"]($bbox);
  nwr["historic"="menhir"]($bbox);
  nwr["historic"="tomb"]($bbox);
  nwr["historic"="stone_circle"]($bbox);
  nwr["historic"="tumulus"]($bbox);
  nwr["historic"="ruins"]($bbox);
  nwr["historic"="monument"]($bbox);
  nwr["historic"="memorial"]($bbox);
  nwr["historic"="castle"]($bbox);
  nwr["historic"="fort"]($bbox);
  nwr["historic"="wayside_cross"]($bbox);
);
out center;
''';
  final json = await consultarOverpass(consulta);
  final elementos = (json['elements'] as List?) ?? const [];
  final monumentos = <MonumentoArqueologico>[];
  for (final e in elementos) {
    final coords = _extraerCoordenadas(e as Map<String, dynamic>);
    if (coords.lat == null || coords.lon == null) continue;
    final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final id = '${e['type']}/${e['id']}';
    final categoria = _categorizar(tags);
    monumentos.add(MonumentoArqueologico(
      id: id,
      latitud: coords.lat!,
      longitud: coords.lon!,
      nombre: (tags['name'] ?? tags['name:eu'] ?? tags['name:es'] ?? tags['name:fr'] ?? 'Sin nombre').toString(),
      tipoOriginal: (tags['archaeological_site'] ?? tags['tomb'] ?? tags['site_type'] ?? tags['historic'] ?? '').toString(),
      tipoLegible: categoria.legible,
      emoji: categoria.emoji,
      descripcion: tags['description']?.toString() ?? tags['description:es']?.toString() ?? tags['description:eu']?.toString(),
      historico: tags['heritage']?.toString() ?? tags['start_date']?.toString(),
      enlaceOSM: 'https://www.openstreetmap.org/${e['type']}/${e['id']}',
    ));
  }
  return monumentos;
}
