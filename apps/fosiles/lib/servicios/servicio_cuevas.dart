import 'servicio_overpass.dart';

class CuevaOSM {
  final String id;
  final double latitud;
  final double longitud;
  final String nombre;
  final String? profundidadMetros;
  final String? longitudMetros;
  final String? tipo;
  final String enlaceOSM;
  CuevaOSM({
    required this.id,
    required this.latitud,
    required this.longitud,
    required this.nombre,
    this.profundidadMetros,
    this.longitudMetros,
    this.tipo,
    required this.enlaceOSM,
  });
}

class LimitesGeograficos {
  final double sur;
  final double norte;
  final double oeste;
  final double este;
  LimitesGeograficos({required this.sur, required this.norte, required this.oeste, required this.este});
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

Future<List<CuevaOSM>> buscarCuevas(LimitesGeograficos limites) async {
  final bbox = '${limites.sur},${limites.oeste},${limites.norte},${limites.este}';
  final consulta = '''
[out:json][timeout:60];
(
  nwr["natural"="cave_entrance"]($bbox);
  nwr["historic"="cave"]($bbox);
  nwr["man_made"="adit"]($bbox);
  nwr["man_made"="mineshaft"]($bbox);
);
out center;
''';
  final json = await consultarOverpass(consulta);
  final elementos = (json['elements'] as List?) ?? const [];
  final cuevas = <CuevaOSM>[];
  for (final e in elementos) {
    final coords = _extraerCoordenadas(e as Map<String, dynamic>);
    if (coords.lat == null || coords.lon == null) continue;
    final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final id = '${e['type']}/${e['id']}';
    final esMina = tags['man_made'] == 'adit' || tags['man_made'] == 'mineshaft';
    final nombrePorDefecto = esMina ? 'Bocamina sin nombre' : 'Cueva sin nombre';
    cuevas.add(CuevaOSM(
      id: id,
      latitud: coords.lat!,
      longitud: coords.lon!,
      nombre: (tags['name'] ?? tags['name:eu'] ?? tags['name:es'] ?? nombrePorDefecto).toString(),
      profundidadMetros: tags['depth']?.toString() ?? tags['cave:depth']?.toString(),
      longitudMetros: tags['length']?.toString() ?? tags['cave:length']?.toString(),
      tipo: tags['cave:type']?.toString() ?? (esMina ? 'mina' : null),
      enlaceOSM: 'https://www.openstreetmap.org/${e['type']}/${e['id']}',
    ));
  }
  return cuevas;
}
