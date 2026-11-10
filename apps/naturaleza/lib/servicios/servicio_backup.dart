import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path_lib;
import 'package:nuevo_ser_core/nuevo_ser_core.dart' show SoleraL10n;
import 'package:path_provider/path_provider.dart';
import '../datos/base_datos.dart';

const _nombreManifiesto = 'naturaleza_backup_manifest.txt';
const _firmaBackup = 'naturaleza-flutter-backup-v1';

Future<File> exportarBackup() async {
  final dirDocs = await getApplicationDocumentsDirectory();
  final rutaDb = path_lib.join(dirDocs.path, 'naturaleza.db');
  final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));

  await BaseDatosNaturaleza.instancia.basedatos;

  final archivo = Archive();
  archivo.addFile(ArchiveFile.string(_nombreManifiesto, _firmaBackup));

  final ficheroDb = File(rutaDb);
  if (await ficheroDb.exists()) {
    final bytes = await ficheroDb.readAsBytes();
    archivo.addFile(ArchiveFile('naturaleza.db', bytes.length, bytes));
  }

  if (await dirFotos.exists()) {
    await for (final entidad in dirFotos.list(recursive: false)) {
      if (entidad is File) {
        final bytes = await entidad.readAsBytes();
        final nombre = path_lib.basename(entidad.path);
        archivo.addFile(ArchiveFile('fotos/$nombre', bytes.length, bytes));
      }
    }
  }

  // Clips de audio de los hallazgos identificados por el sonido.
  final dirAudios = Directory(path_lib.join(dirDocs.path, 'audios'));
  if (await dirAudios.exists()) {
    await for (final entidad in dirAudios.list(recursive: false)) {
      if (entidad is File) {
        final bytes = await entidad.readAsBytes();
        final nombre = path_lib.basename(entidad.path);
        archivo.addFile(ArchiveFile('audios/$nombre', bytes.length, bytes));
      }
    }
  }

  final dirTemp = await getTemporaryDirectory();
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  final destino = File(path_lib.join(dirTemp.path, 'naturaleza_backup_$timestamp.natbackup'));
  final encoder = ZipEncoder();
  await destino.writeAsBytes(encoder.encode(archivo)!);
  return destino;
}

class ResultadoRestauracion {
  final int hallazgosRestaurados;
  final int fotosRestauradas;
  ResultadoRestauracion({required this.hallazgosRestaurados, required this.fotosRestauradas});
}

Future<ResultadoRestauracion> restaurarBackup(File ficheroBackup) async {
  final bytes = await ficheroBackup.readAsBytes();
  final decoder = ZipDecoder();
  final archivo = decoder.decodeBytes(bytes);

  final manifiesto = archivo.firstWhere((f) => f.name == _nombreManifiesto, orElse: () => throw Exception(SoleraL10n.t('fos.ajus_fichero_no_valido')));
  final contenido = String.fromCharCodes(manifiesto.content as List<int>);
  if (!contenido.contains('naturaleza-flutter-backup')) {
    throw Exception(SoleraL10n.t('fos.ajus_version_desconocida'));
  }

  final dirDocs = await getApplicationDocumentsDirectory();
  final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));
  if (!await dirFotos.exists()) await dirFotos.create(recursive: true);

  await BaseDatosNaturaleza.instancia.cerrar();

  int hallazgos = 0;
  int fotos = 0;
  for (final fichero in archivo.files) {
    if (fichero.name == 'naturaleza.db') {
      final destino = File(path_lib.join(dirDocs.path, 'naturaleza.db'));
      await destino.writeAsBytes(fichero.content as List<int>);
    } else if (fichero.name.startsWith('fotos/')) {
      final nombre = path_lib.basename(fichero.name);
      final destino = File(path_lib.join(dirFotos.path, nombre));
      await destino.writeAsBytes(fichero.content as List<int>);
      fotos++;
    } else if (fichero.name.startsWith('audios/')) {
      final dirAudios = Directory(path_lib.join(dirDocs.path, 'audios'));
      if (!await dirAudios.exists()) await dirAudios.create(recursive: true);
      final nombre = path_lib.basename(fichero.name);
      await File(path_lib.join(dirAudios.path, nombre)).writeAsBytes(fichero.content as List<int>);
    }
  }

  final db = await BaseDatosNaturaleza.instancia.basedatos;
  final result = await db.rawQuery('SELECT COUNT(*) as n FROM hallazgos');
  hallazgos = (result.first['n'] as int?) ?? 0;
  return ResultadoRestauracion(hallazgosRestaurados: hallazgos, fotosRestauradas: fotos);
}
