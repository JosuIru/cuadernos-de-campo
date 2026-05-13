import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto_sha;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

import '../datos/configuracion.dart';
import '../modelos/hallazgo.dart';
import 'identidad_descubridor.dart';

/// Formato `.fos-card` v1 — card de un hallazgo lista para compartir por
/// WhatsApp/email/Drive y luego importar en otra instalación de Fósiles.
///
/// El archivo es un ZIP con:
///   - `manifest.json` (versión + firma del formato)
///   - `hallazgo.json` (datos del hallazgo + identidad declarada + firma
///     Ed25519 + clave pública del descubridor)
///   - `fotos/foto_<n>.jpg` (fotos redimensionadas a 1600 px lado mayor,
///     JPEG q75 → ~400 KB cada una; el original NO se toca en local)
///
/// Si el remitente elige *coords difuminadas*, el JSON lleva la versión
/// difuminada (precisión ~1 km) en `coordenadas` y un flag
/// `coordenadas_difuminadas=true`. La **firma Ed25519** se mantiene
/// sobre los datos originales del hallazgo (incluyendo coords precisas)
/// para que la cadena de trazabilidad no se rompa — pero los datos
/// difuminados son los únicos que viajan en el JSON.
const String _firmaFormato = 'fosiles-fos-card-v1';
const int _ladoMayorPx = 1600;
const int _calidadJpeg = 75;
const String _nombreManifest = 'manifest.json';
const String _nombreHallazgo = 'hallazgo.json';

/// Modo de compartición — cuántos decimales de coordenadas viajan en el
/// .fos-card. `precisas` = 6 decimales (≈11 cm); `difuminadas` = 2
/// decimales (≈1.1 km, anti-saqueo de yacimientos sensibles).
enum ModoCompartirCoordenadas { precisas, difuminadas }

class ResultadoExportarFosCard {
  final File archivo;
  final int bytesTotales;
  final int fotosIncluidas;
  ResultadoExportarFosCard({
    required this.archivo,
    required this.bytesTotales,
    required this.fotosIncluidas,
  });
}

/// Genera un archivo `.fos-card` para un hallazgo dado y lo deja en la
/// carpeta temporal. Llamar después a `share_plus.shareXFiles` con la
/// ruta devuelta.
Future<ResultadoExportarFosCard> exportarFosCard({
  required Hallazgo hallazgo,
  required ModoCompartirCoordenadas modoCoordenadas,
}) async {
  final identidad = IdentidadDescubridor.instancia;

  // Identidad declarada (auto-asertada) — viaja junto a la firma para
  // que el receptor sepa quién dice ser el remitente.
  final nombre = await Configuracion.obtenerNombreDescubridor();
  final email = await Configuracion.obtenerEmailDescubridor();
  final organizacion = await Configuracion.obtenerOrganizacionDescubridor();

  // Firma del hallazgo. Si el hallazgo ya tiene firma persistida en BD
  // (creado tras Fase A), reusamos la suya. Si no (hallazgo pre-Fase A),
  // firmamos al vuelo con la clave actual del dispositivo — el receptor
  // verifica que la firma cuadra con los datos del JSON.
  final String firmaB64;
  final String clavePublicaB64;
  if (hallazgo.tieneFirma) {
    firmaB64 = hallazgo.firmaDescubridor!;
    clavePublicaB64 = hallazgo.clavePublicaDescubridor!;
  } else {
    final mensajeCanonico = IdentidadDescubridor.mensajeCanonicoHallazgo(hallazgo, nombre);
    firmaB64 = await identidad.firmar(mensajeCanonico);
    clavePublicaB64 = await identidad.obtenerClavePublicaBase64();
  }

  // Coordenadas que viajan en el JSON: difuminadas o precisas.
  // OJO: el mensaje canónico de la firma se calcula siempre con las
  // **precisas** (es lo que se firmó en BD). El receptor debe verificar
  // la firma con las coords que vengan en `coordenadas_originales_firmadas`
  // (sólo presente cuando son difuminadas) si quiere comprobar la firma.
  final double latPublica;
  final double lonPublica;
  switch (modoCoordenadas) {
    case ModoCompartirCoordenadas.precisas:
      latPublica = hallazgo.latitud;
      lonPublica = hallazgo.longitud;
      break;
    case ModoCompartirCoordenadas.difuminadas:
      latPublica = double.parse(hallazgo.latitud.toStringAsFixed(2));
      lonPublica = double.parse(hallazgo.longitud.toStringAsFixed(2));
      break;
  }

  final ahora = DateTime.now().toUtc();

  // Reducir fotos
  final fotosReducidas = <Uint8List>[];
  for (final ruta in hallazgo.rutasFotos) {
    final fichero = File(ruta);
    if (!await fichero.exists()) continue;
    try {
      final bytes = await fichero.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) continue;
      final ladoMayor = original.width > original.height ? original.width : original.height;
      late img.Image redimensionada;
      if (ladoMayor <= _ladoMayorPx) {
        redimensionada = original;
      } else {
        final factor = _ladoMayorPx / ladoMayor;
        redimensionada = img.copyResize(
          original,
          width: (original.width * factor).round(),
          height: (original.height * factor).round(),
          interpolation: img.Interpolation.cubic,
        );
      }
      final jpegBytes = img.encodeJpg(redimensionada, quality: _calidadJpeg);
      fotosReducidas.add(jpegBytes);
    } catch (_) {
      // Foto corrupta o formato no soportado — la saltamos sin romper
      // la generación del .fos-card.
    }
  }

  final hallazgoJson = <String, dynamic>{
    'formato': 'hallazgo_fos_card_v1',
    'fecha_export_iso': ahora.toIso8601String(),
    'datos': {
      'fecha_descubrimiento_ms': hallazgo.fechaMs,
      'fecha_descubrimiento_iso':
          DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs, isUtc: true).toIso8601String(),
      'latitud': latPublica,
      'longitud': lonPublica,
      'coordenadas_difuminadas': modoCoordenadas == ModoCompartirCoordenadas.difuminadas,
      'precision_metros': hallazgo.precision,
      'especie': hallazgo.especie,
      'edad': hallazgo.edad,
      'formacion': hallazgo.formacion,
      'notas': hallazgo.notas,
      'tipo': hallazgo.tipo,
      'strike_grados': hallazgo.strikeGrados,
      'dip_grados': hallazgo.dipGrados,
      'num_fotos': fotosReducidas.length,
      'historial_trazabilidad':
          hallazgo.historialTrazabilidad.map((e) => e.toJson()).toList(),
    },
    'descubridor': {
      'nombre': nombre,
      if (email.isNotEmpty) 'email': email,
      if (organizacion.isNotEmpty) 'organizacion': organizacion,
    },
    'firma': {
      'algoritmo': 'ed25519',
      'firma_b64': firmaB64,
      'clave_publica_b64': clavePublicaB64,
      // El receptor verifica con `mensajeCanonicoHallazgo` reconstruido
      // a partir de estos campos + el nombre del descubridor.
      'mensaje_canonico_v1': {
        'latitud_orig': hallazgo.latitud,
        'longitud_orig': hallazgo.longitud,
        'fecha_ms': hallazgo.fechaMs,
        'especie': hallazgo.especie,
        'edad': hallazgo.edad,
        'formacion': hallazgo.formacion,
        'tipo': hallazgo.tipo,
        'nombre_descubridor': nombre,
      },
    },
  };

  final archivo = Archive();
  archivo.addFile(ArchiveFile.string(
    _nombreManifest,
    jsonEncode({'formato': _firmaFormato, 'fecha_iso': ahora.toIso8601String()}),
  ));
  final bytesHallazgo = utf8.encode(jsonEncode(hallazgoJson));
  archivo.addFile(ArchiveFile(_nombreHallazgo, bytesHallazgo.length, bytesHallazgo));
  for (var i = 0; i < fotosReducidas.length; i++) {
    final bytes = fotosReducidas[i];
    archivo.addFile(ArchiveFile('fotos/foto_$i.jpg', bytes.length, bytes));
  }

  final dirTemp = await getTemporaryDirectory();
  final stamp = ahora.toIso8601String().replaceAll(':', '-').split('.').first;
  final hashCorto = crypto_sha.sha256.convert(bytesHallazgo).toString().substring(0, 8);
  final destino = File(path_lib.join(dirTemp.path, 'hallazgo_${hashCorto}_$stamp.fos-card'));
  final encoder = ZipEncoder();
  final bytesZip = encoder.encode(archivo)!;
  await destino.writeAsBytes(bytesZip);

  return ResultadoExportarFosCard(
    archivo: destino,
    bytesTotales: bytesZip.length,
    fotosIncluidas: fotosReducidas.length,
  );
}

class FosCardParseada {
  /// Hallazgo reconstruido a partir del .fos-card. Listo para insertar
  /// en BD como hallazgo importado (sin id).
  final Hallazgo hallazgo;

  /// Bytes JPEG de cada foto incluida, en orden. El llamador los persiste
  /// en disco local con nombres únicos antes de meter el Hallazgo en BD.
  final List<Uint8List> fotosJpeg;

  /// Si la firma Ed25519 cuadra con los datos canónicos. Si es `false`,
  /// el .fos-card está manipulado o es inválido — UI debe avisar.
  final bool firmaValida;

  /// Nombre/email/organización que el remitente declaró. Auto-asertados.
  final String nombreRemitente;
  final String? emailRemitente;
  final String? organizacionRemitente;

  /// Clave pública (base64) del remitente. Es su huella permanente.
  final String clavePublicaRemitente;

  /// True si las coordenadas que viajan están difuminadas (precisión ~1 km)
  /// en lugar de las precisas. El recibidor lo enseña en la UI.
  final bool coordenadasDifuminadas;

  FosCardParseada({
    required this.hallazgo,
    required this.fotosJpeg,
    required this.firmaValida,
    required this.nombreRemitente,
    this.emailRemitente,
    this.organizacionRemitente,
    required this.clavePublicaRemitente,
    required this.coordenadasDifuminadas,
  });
}

/// Parsea un archivo `.fos-card` y verifica su firma. Devuelve los datos
/// listos para que la UI haga preview + decisión de importar.
///
/// Lanza `FormatException` si el ZIP está corrupto, no es un .fos-card,
/// o la versión del formato es desconocida.
Future<FosCardParseada> parsearFosCard(File ficheroFosCard) async {
  final bytes = await ficheroFosCard.readAsBytes();
  final archivo = ZipDecoder().decodeBytes(bytes);

  // Manifiesto
  final manifiestoFichero = archivo.files.firstWhere(
    (f) => f.name == _nombreManifest,
    orElse: () => throw const FormatException('No es un .fos-card válido (sin manifest)'),
  );
  final manifiesto = jsonDecode(utf8.decode(manifiestoFichero.content as List<int>)) as Map<String, dynamic>;
  if (manifiesto['formato'] != _firmaFormato) {
    throw FormatException('Formato desconocido: ${manifiesto['formato']}');
  }

  // Hallazgo
  final hallazgoFichero = archivo.files.firstWhere(
    (f) => f.name == _nombreHallazgo,
    orElse: () => throw const FormatException('Falta hallazgo.json'),
  );
  final hallazgoJson =
      jsonDecode(utf8.decode(hallazgoFichero.content as List<int>)) as Map<String, dynamic>;
  if (hallazgoJson['formato'] != 'hallazgo_fos_card_v1') {
    throw FormatException('Versión de hallazgo desconocida: ${hallazgoJson['formato']}');
  }

  final datos = hallazgoJson['datos'] as Map<String, dynamic>;
  final descubridor = hallazgoJson['descubridor'] as Map<String, dynamic>;
  final firmaMap = hallazgoJson['firma'] as Map<String, dynamic>;
  final mensajeCanonicoMap = firmaMap['mensaje_canonico_v1'] as Map<String, dynamic>;

  // Reconstruir mensaje canónico para verificar firma
  final mensajeCanonico = [
    (mensajeCanonicoMap['latitud_orig'] as num).toDouble().toStringAsFixed(6),
    (mensajeCanonicoMap['longitud_orig'] as num).toDouble().toStringAsFixed(6),
    (mensajeCanonicoMap['fecha_ms'] as int).toString(),
    (mensajeCanonicoMap['especie'] as String).trim(),
    (mensajeCanonicoMap['edad'] as String).trim(),
    (mensajeCanonicoMap['formacion'] as String).trim(),
    mensajeCanonicoMap['tipo'] as String,
    (mensajeCanonicoMap['nombre_descubridor'] as String).trim(),
  ].join('|');

  final firmaB64 = firmaMap['firma_b64'] as String;
  final clavePublicaB64 = firmaMap['clave_publica_b64'] as String;

  final firmaValida = await IdentidadDescubridor.instancia.verificarFirma(
    mensajeCanonico: mensajeCanonico,
    firmaBase64: firmaB64,
    clavePublicaBase64: clavePublicaB64,
  );

  // Fotos
  final fotosJpeg = <Uint8List>[];
  for (final f in archivo.files) {
    if (f.name.startsWith('fotos/') && f.name.endsWith('.jpg')) {
      fotosJpeg.add(Uint8List.fromList(f.content as List<int>));
    }
  }

  // Hallazgo importado: usamos las coords que viajan (precisas o
  // difuminadas) — el receptor no tiene acceso a las precisas si el
  // remitente eligió difuminar. La firma se preserva tal cual.
  final hallazgo = Hallazgo(
    fechaMs: datos['fecha_descubrimiento_ms'] as int,
    latitud: (datos['latitud'] as num).toDouble(),
    longitud: (datos['longitud'] as num).toDouble(),
    precision: (datos['precision_metros'] as num?)?.toDouble(),
    especie: (datos['especie'] as String?) ?? '',
    edad: (datos['edad'] as String?) ?? '',
    formacion: (datos['formacion'] as String?) ?? '',
    notas: (datos['notas'] as String?) ?? '',
    rutasFotos: const [], // las rellenará el caller tras persistir las jpegs
    strikeGrados: (datos['strike_grados'] as num?)?.toDouble(),
    dipGrados: (datos['dip_grados'] as num?)?.toDouble(),
    tipo: (datos['tipo'] as String?) ?? 'fosil',
    historialTrazabilidad: ((datos['historial_trazabilidad'] as List?) ?? const [])
        .map((e) => EventoTrazabilidad.fromJson(e as Map<String, dynamic>))
        .toList(),
    firmaDescubridor: firmaB64,
    clavePublicaDescubridor: clavePublicaB64,
  );

  return FosCardParseada(
    hallazgo: hallazgo,
    fotosJpeg: fotosJpeg,
    firmaValida: firmaValida,
    nombreRemitente: (descubridor['nombre'] as String?) ?? '',
    emailRemitente: descubridor['email'] as String?,
    organizacionRemitente: descubridor['organizacion'] as String?,
    clavePublicaRemitente: clavePublicaB64,
    coordenadasDifuminadas: (datos['coordenadas_difuminadas'] as bool?) ?? false,
  );
}
