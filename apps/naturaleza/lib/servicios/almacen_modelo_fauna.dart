import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

import '../sonido/filtro_ocurrencia.dart';
import '../sonido/manifiesto_modelo_fauna.dart';

/// Descarga, comprobación y borrado del modelo de fauna de «¿Quién canta?».
///
/// El modelo no va en el APK (pesa ≈37 MB): se descarga una vez de la
/// release pública de Laboratorio de Bolsillo a la carpeta de documentos y
/// desde entonces funciona sin conexión. El SHA-256 se calcula mientras se
/// descarga y se compara con el del manifiesto; el manifiesto se escribe el
/// último: si está, el modelo está completo.

/// Release de GitHub con el modelo (Perch 2.0 recortado a Europa).
const String urlBaseReleaseModeloFauna =
    'https://github.com/JosuIru/laboratorio-de-bolsillo/releases/download/modelo-fauna-europa-1/';
const String _nombreManifiesto = 'fauna-manifest.json';

/// Tamaño aproximado que se anuncia antes de saber el exacto.
const int megabytesAproximadosModelo = 37;

Future<Directory> carpetaModeloFauna() async {
  final documentos = await getApplicationDocumentsDirectory();
  return Directory(path_lib.join(documentos.path, 'modelo_fauna'));
}

class ModeloFaunaInstalado {
  final ManifiestoFauna manifiesto;
  final String rutaModelo;
  const ModeloFaunaInstalado(this.manifiesto, this.rutaModelo);
}

/// Modelo ya descargado y completo, o `null`. No lanza.
Future<ModeloFaunaInstalado?> leerModeloFaunaInstalado() async {
  try {
    final carpeta = await carpetaModeloFauna();
    final ficheroManifiesto = File(path_lib.join(carpeta.path, _nombreManifiesto));
    if (!await ficheroManifiesto.exists()) return null;
    final manifiesto = leerManifiestoFauna(jsonDecode(await ficheroManifiesto.readAsString()));
    final ficheroModelo = File(path_lib.join(carpeta.path, manifiesto.ficheroModelo));
    if (!await ficheroModelo.exists() || await ficheroModelo.length() != manifiesto.bytesModelo) {
      return null;
    }
    return ModeloFaunaInstalado(manifiesto, ficheroModelo.path);
  } catch (_) {
    return null;
  }
}

/// Descarga y valida el manifiesto (≈160 kB): da el tamaño exacto antes de
/// bajar el modelo.
Future<ManifiestoFauna> descargarManifiestoFaunaRemoto() async {
  final respuesta = await http
      .get(Uri.parse('$urlBaseReleaseModeloFauna$_nombreManifiesto'))
      .timeout(const Duration(seconds: 30));
  if (respuesta.statusCode != 200) throw HttpException('HTTP ${respuesta.statusCode}');
  return leerManifiestoFauna(jsonDecode(utf8.decode(respuesta.bodyBytes)));
}

/// Permite cancelar una descarga en curso.
class CancelacionDescarga {
  bool _cancelada = false;
  http.Client? _cliente;
  bool get cancelada => _cancelada;
  void cancelar() {
    _cancelada = true;
    _cliente?.close();
  }
}

class DescargaCancelada implements Exception {
  const DescargaCancelada();
}

/// Descarga el modelo del manifiesto, lo comprueba (tamaño y SHA-256) y lo
/// deja instalado. [alProgreso] recibe bytes recibidos y totales.
Future<ModeloFaunaInstalado> descargarModeloFauna(
  ManifiestoFauna manifiesto, {
  required void Function(int bytesRecibidos, int bytesTotales) alProgreso,
  required CancelacionDescarga cancelacion,
}) async {
  // Solo un modelo instalado a la vez: se borra lo anterior.
  await borrarModeloFaunaInstalado();
  final carpeta = await carpetaModeloFauna();
  await carpeta.create(recursive: true);
  final ficheroModelo = File(path_lib.join(carpeta.path, manifiesto.ficheroModelo));
  final ficheroParcial = File('${ficheroModelo.path}.parcial');
  final cliente = http.Client();
  cancelacion._cliente = cliente;
  IOSink? escritura;
  try {
    final respuesta = await cliente.send(
        http.Request('GET', Uri.parse('$urlBaseReleaseModeloFauna${manifiesto.ficheroModelo}')));
    if (respuesta.statusCode != 200) throw HttpException('HTTP ${respuesta.statusCode}');
    final bytesTotales = (respuesta.contentLength ?? 0) > 0
        ? respuesta.contentLength!
        : manifiesto.bytesModelo;
    escritura = ficheroParcial.openWrite();
    final recolectorHash = _RecolectorDigest();
    final conversionHash = sha256.startChunkedConversion(recolectorHash);
    var bytesRecibidos = 0;
    await for (final bloque in respuesta.stream) {
      if (cancelacion.cancelada) throw const DescargaCancelada();
      escritura.add(bloque);
      conversionHash.add(bloque);
      bytesRecibidos += bloque.length;
      alProgreso(bytesRecibidos, bytesTotales);
    }
    await escritura.flush();
    await escritura.close();
    escritura = null;
    conversionHash.close();
    if (cancelacion.cancelada) throw const DescargaCancelada();
    comprobarIntegridadModelo(
      manifiesto: manifiesto,
      bytesDescargados: await ficheroParcial.length(),
      sha256Descargado: recolectorHash.resultado.toString(),
    );
    await ficheroParcial.rename(ficheroModelo.path);
    await File(path_lib.join(carpeta.path, _nombreManifiesto))
        .writeAsString(jsonEncode(manifiesto.jsonOriginal), flush: true);
    return ModeloFaunaInstalado(manifiesto, ficheroModelo.path);
  } catch (error) {
    try {
      await escritura?.close();
    } catch (_) {}
    await borrarModeloFaunaInstalado();
    if (cancelacion.cancelada) throw const DescargaCancelada();
    rethrow;
  } finally {
    cliente.close();
    cancelacion._cliente = null;
  }
}

class _RecolectorDigest implements Sink<Digest> {
  Digest? _digest;
  Digest get resultado => _digest!;
  @override
  void add(Digest data) => _digest = data;
  @override
  void close() {}
}

/// Borra el modelo, su manifiesto y el fichero de presencia (todo va en la
/// misma carpeta). No lanza.
Future<void> borrarModeloFaunaInstalado() async {
  try {
    final carpeta = await carpetaModeloFauna();
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
  } catch (_) {
    // Si no se puede borrar, la próxima descarga lo sobrescribe.
  }
}

/// Presencia ya descargada y válida, o `null`. No lanza.
Future<DatosOcurrencia?> leerOcurrenciaInstalada(ManifiestoFauna manifiesto) async {
  try {
    final carpeta = await carpetaModeloFauna();
    final fichero = File(path_lib.join(carpeta.path, manifiesto.ficheroOcurrencia));
    if (!await fichero.exists()) return null;
    return leerDatosOcurrencia(jsonDecode(await fichero.readAsString()));
  } catch (_) {
    return null;
  }
}

/// Descarga, valida y guarda el fichero de presencia (≈170 kB). Es opcional:
/// si falla, se escucha sin filtro y se reintenta la próxima vez.
Future<DatosOcurrencia> descargarOcurrencia(ManifiestoFauna manifiesto) async {
  final respuesta = await http
      .get(Uri.parse('$urlBaseReleaseModeloFauna${manifiesto.ficheroOcurrencia}'))
      .timeout(const Duration(seconds: 60));
  if (respuesta.statusCode != 200) throw HttpException('HTTP ${respuesta.statusCode}');
  final texto = utf8.decode(respuesta.bodyBytes);
  // Se valida antes de guardarlo: un fichero roto no debe quedarse instalado.
  final datos = leerDatosOcurrencia(jsonDecode(texto));
  final carpeta = await carpetaModeloFauna();
  // Si el modelo se ha borrado mientras tanto, no se recrea la carpeta.
  if (await carpeta.exists()) {
    await File(path_lib.join(carpeta.path, manifiesto.ficheroOcurrencia)).writeAsString(texto);
  }
  return datos;
}
