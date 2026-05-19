import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../datos/base_datos.dart';
import 'identidad_descubridor.dart';

const _nombreManifiesto = 'fosiles_backup_manifest.txt';
const _firmaBackup = 'fosiles-flutter-backup-v2';
const _nombreIdentidad = 'identidad_descubridor.json';

Future<File> exportarBackup() async {
  final dirDocs = await getApplicationDocumentsDirectory();
  final rutaDb = path_lib.join(dirDocs.path, 'fosiles.db');
  final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));

  await BaseDatosFosiles.instancia.basedatos;

  final archivo = Archive();
  archivo.addFile(ArchiveFile.string(_nombreManifiesto, _firmaBackup));

  final ficheroDb = File(rutaDb);
  if (await ficheroDb.exists()) {
    final bytes = await ficheroDb.readAsBytes();
    archivo.addFile(ArchiveFile('fosiles.db', bytes.length, bytes));
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

  // Identidad criptográfica del descubridor (Fase A). Se incluye la
  // semilla Ed25519 para que al restaurar el backup en otro dispositivo
  // (o en el mismo tras un wipe) el usuario recupere su huella permanente
  // y siga firmando hallazgos con la misma clave. El backup .zip ya es la
  // unidad cifrable que comparte el usuario; la semilla viaja dentro
  // junto a sus datos.
  try {
    final semilla = await IdentidadDescubridor.instancia.exportarSemillaBase64();
    final clavePublica = await IdentidadDescubridor.instancia.obtenerClavePublicaBase64();
    final json = jsonEncode({
      'tipo': 'identidad_descubridor_fosiles',
      'algoritmo': 'ed25519',
      'semilla_b64': semilla,
      'clave_publica_b64': clavePublica,
    });
    final bytes = utf8.encode(json);
    archivo.addFile(ArchiveFile(_nombreIdentidad, bytes.length, bytes));
  } catch (_) {
    // Si la identidad no se puede leer (Keystore bloqueado, etc.), el
    // backup sigue siendo útil para los datos y fotos — sólo se pierde
    // la portabilidad de la identidad criptográfica.
  }

  final dirTemp = await getTemporaryDirectory();
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  final destino = File(path_lib.join(dirTemp.path, 'fosiles_backup_$timestamp.fosbackup'));
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

  final manifiesto = archivo.firstWhere((f) => f.name == _nombreManifiesto, orElse: () => throw Exception('No es un fichero de copia válido'));
  final contenido = String.fromCharCodes(manifiesto.content as List<int>);
  if (!contenido.contains('fosiles-flutter-backup')) {
    throw Exception('Versión de copia desconocida');
  }

  final dirDocs = await getApplicationDocumentsDirectory();
  final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));
  if (!await dirFotos.exists()) await dirFotos.create(recursive: true);

  await BaseDatosFosiles.instancia.cerrar();

  int hallazgos = 0;
  int fotos = 0;
  String? semillaIdentidadPendiente;
  for (final fichero in archivo.files) {
    if (fichero.name == 'fosiles.db') {
      final destino = File(path_lib.join(dirDocs.path, 'fosiles.db'));
      await destino.writeAsBytes(fichero.content as List<int>);
    } else if (fichero.name.startsWith('fotos/')) {
      final nombre = path_lib.basename(fichero.name);
      final destino = File(path_lib.join(dirFotos.path, nombre));
      await destino.writeAsBytes(fichero.content as List<int>);
      fotos++;
    } else if (fichero.name == _nombreIdentidad) {
      final contenidoIdentidad = utf8.decode(fichero.content as List<int>);
      try {
        final mapa = jsonDecode(contenidoIdentidad) as Map<String, dynamic>;
        if (mapa['algoritmo'] == 'ed25519' && mapa['semilla_b64'] is String) {
          semillaIdentidadPendiente = mapa['semilla_b64'] as String;
        }
      } catch (_) {
        // Identidad corrupta — el resto del backup sigue restaurándose.
      }
    }
  }

  // Restaurar la identidad criptográfica del descubridor ANTES de
  // reabrir la BD: así, si el usuario crea un hallazgo inmediatamente
  // después de restaurar, ya firma con la clave correcta.
  if (semillaIdentidadPendiente != null) {
    try {
      await IdentidadDescubridor.instancia.importarSemilla(semillaIdentidadPendiente);
    } catch (_) {
      // Continuamos: la BD y fotos se restauran aunque la identidad
      // no se haya podido reescribir en el Keystore.
    }
  }

  final db = await BaseDatosFosiles.instancia.basedatos;
  final result = await db.rawQuery('SELECT COUNT(*) as n FROM hallazgos');
  hallazgos = (result.first['n'] as int?) ?? 0;
  return ResultadoRestauracion(hallazgosRestaurados: hallazgos, fotosRestauradas: fotos);
}
