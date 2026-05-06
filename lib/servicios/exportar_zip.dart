import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../modelos/hallazgo.dart';

Future<File> generarZipHallazgos(List<Hallazgo> hallazgos) async {
  final archivo = Archive();

  // GeoJSON
  final geojson = <String, dynamic>{
    'type': 'FeatureCollection',
    'features': hallazgos.map((h) {
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [h.longitud, h.latitud],
        },
        'properties': {
          'id': h.id,
          'fecha': DateTime.fromMillisecondsSinceEpoch(h.fechaMs).toIso8601String(),
          'especie': h.especie,
          'edad': h.edad,
          'formacion': h.formacion,
          'notas': h.notas,
          'precision_m': h.precision,
          'foto': h.rutaFoto != null ? 'fotos/${path_lib.basename(h.rutaFoto!)}' : null,
        },
      };
    }).toList(),
  };
  final geojsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(geojson));
  archivo.addFile(ArchiveFile('hallazgos.geojson', geojsonBytes.length, geojsonBytes));

  // CSV
  final formatoFecha = DateFormat('yyyy-MM-dd HH:mm:ss');
  final csvBuffer = StringBuffer()
    ..writeln('id,fecha,latitud,longitud,precision_m,especie,edad,formacion,notas,foto');
  for (final h in hallazgos) {
    String escapar(String? texto) {
      final t = (texto ?? '').replaceAll('"', '""').replaceAll('\n', ' ');
      return '"$t"';
    }

    csvBuffer.writeln([
      h.id ?? '',
      escapar(formatoFecha.format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs))),
      h.latitud,
      h.longitud,
      h.precision ?? '',
      escapar(h.especie),
      escapar(h.edad),
      escapar(h.formacion),
      escapar(h.notas),
      escapar(h.rutaFoto != null ? 'fotos/${path_lib.basename(h.rutaFoto!)}' : ''),
    ].join(','));
  }
  final csvBytes = utf8.encode(csvBuffer.toString());
  archivo.addFile(ArchiveFile('hallazgos.csv', csvBytes.length, csvBytes));

  // Fotos
  for (final h in hallazgos) {
    if (h.rutaFoto == null) continue;
    final foto = File(h.rutaFoto!);
    if (!await foto.exists()) continue;
    final bytes = await foto.readAsBytes();
    archivo.addFile(ArchiveFile('fotos/${path_lib.basename(h.rutaFoto!)}', bytes.length, bytes));
  }

  final encoder = ZipEncoder();
  final zipBytes = encoder.encode(archivo);
  if (zipBytes == null) throw Exception('No se pudo generar el ZIP.');

  final dirCache = await getTemporaryDirectory();
  final marca = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final destino = File(path_lib.join(dirCache.path, 'fosiles_$marca.zip'));
  await destino.writeAsBytes(zipBytes, flush: true);
  return destino;
}
