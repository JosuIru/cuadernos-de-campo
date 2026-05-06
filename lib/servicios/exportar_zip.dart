import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../modelos/hallazgo.dart';

Future<File> generarZipHallazgos(List<Hallazgo> hallazgos) async {
  final archivo = Archive();

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
          'categoria': h.categoria,
          'especie': h.especie,
          'nombre_comun': h.nombreComun,
          'taxonomia': h.taxonomia,
          'habitat': h.habitat,
          'notas': h.notas,
          'precision_m': h.precision,
          'foto': h.rutaFoto != null ? 'fotos/${path_lib.basename(h.rutaFoto!)}' : null,
          'atributos': h.atributos,
        },
      };
    }).toList(),
  };
  final geojsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(geojson));
  archivo.addFile(ArchiveFile('hallazgos.geojson', geojsonBytes.length, geojsonBytes));

  final formatoFecha = DateFormat('yyyy-MM-dd HH:mm:ss');
  final csvBuffer = StringBuffer()
    ..writeln('id,fecha,latitud,longitud,precision_m,categoria,especie,nombre_comun,taxonomia,habitat,notas,foto');
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
      escapar(h.categoria),
      escapar(h.especie),
      escapar(h.nombreComun),
      escapar(h.taxonomia),
      escapar(h.habitat),
      escapar(h.notas),
      escapar(h.rutaFoto != null ? 'fotos/${path_lib.basename(h.rutaFoto!)}' : ''),
    ].join(','));
  }
  final csvBytes = utf8.encode(csvBuffer.toString());
  archivo.addFile(ArchiveFile('hallazgos.csv', csvBytes.length, csvBytes));

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
  final destino = File(path_lib.join(dirCache.path, 'naturaleza_$marca.zip'));
  await destino.writeAsBytes(zipBytes, flush: true);
  return destino;
}
