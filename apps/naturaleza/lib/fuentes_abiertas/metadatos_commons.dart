/// Autor y licencia de las fotos de Wikimedia Commons de la galería de
/// Wikipedia (API `imageinfo` con `extmetadata`: Artist, LicenseShortName,
/// LicenseUrl). Lógica pura: qué fichero es cada URL, la petición, el
/// parseo y qué licencias se aceptan.
///
/// Se aceptan solo licencias libres claras: **CC0, dominio público, CC BY y
/// CC BY-SA** (cualquier versión o adaptación nacional). Nunca NC ni ND, ni
/// ficheros marcados `NonFree`, ni otras (GFDL sola, Free Art License,
/// «Attribution» suelta…): ante la duda, la foto no se enseña. Las CC BY y
/// BY-SA sin autor tampoco (no se podría atribuir).
library;

/// Clase de licencia aceptada.
enum LicenciaCommons { dominioPublico, cc0, ccBy, ccBySa }

class MetadatosFotoCommons {
  /// Nombre del fichero con espacios (`Erithacus rubecula.jpg`).
  final String archivo;

  /// Autor en texto plano; null solo en dominio público o CC0.
  final String? autor;
  final LicenciaCommons licencia;

  /// Nombre corto tal como lo da Commons (`CC BY-SA 4.0`).
  final String licenciaCorta;
  final String? urlLicencia;

  /// Página del fichero en Commons.
  final String? urlDescripcion;

  const MetadatosFotoCommons({
    required this.archivo,
    required this.autor,
    required this.licencia,
    required this.licenciaCorta,
    this.urlLicencia,
    this.urlDescripcion,
  });

  bool get sinDerechos => licencia == LicenciaCommons.dominioPublico || licencia == LicenciaCommons.cc0;

  /// «© autor · CC BY-SA 4.0»; en dominio público o CC0 sin «©».
  String get textoAtribucion {
    final partes = <String>[
      if (autor != null && autor!.isNotEmpty) sinDerechos ? autor! : '© ${autor!}',
      licenciaCorta,
    ];
    return partes.join(' · ');
  }

  Map<String, Object?> aJson() => {
        'archivo': archivo,
        'autor': autor,
        'licencia': licencia.name,
        'licencia_corta': licenciaCorta,
        'url_licencia': urlLicencia,
        'url_descripcion': urlDescripcion,
      };

  static MetadatosFotoCommons? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;
    final archivo = crudo['archivo'];
    final licenciaCorta = crudo['licencia_corta'];
    final licencia = LicenciaCommons.values.where((valor) => valor.name == crudo['licencia']).firstOrNull;
    if (archivo is! String || licenciaCorta is! String || licencia == null) return null;
    return MetadatosFotoCommons(
      archivo: archivo,
      autor: crudo['autor'] as String?,
      licencia: licencia,
      licenciaCorta: licenciaCorta,
      urlLicencia: crudo['url_licencia'] as String?,
      urlDescripcion: crudo['url_descripcion'] as String?,
    );
  }
}

final RegExp _rutaCommons = RegExp(
    r'^https?://upload\.wikimedia\.org/wikipedia/commons/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?#]+)');

/// Nombre del fichero de Commons (con espacios) de una URL de
/// `upload.wikimedia.org/wikipedia/commons/…`, original o miniatura. Null si
/// la imagen no es de Commons (las subidas locales de una Wikipedia suelen
/// ser no libres: no se enseñan).
String? archivoCommonsDesdeUrl(String url) {
  final completa = url.startsWith('//') ? 'https:$url' : url;
  final coincidencia = _rutaCommons.firstMatch(completa);
  if (coincidencia == null) return null;
  try {
    return normalizarNombreArchivoCommons(Uri.decodeComponent(coincidencia.group(1)!));
  } catch (_) {
    return null;
  }
}

/// Como lo normaliza MediaWiki: guiones bajos a espacios, sin espacios
/// sobrantes y la primera letra en mayúscula.
String normalizarNombreArchivoCommons(String nombre) {
  var limpio = nombre.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (limpio.toLowerCase().startsWith('file:')) limpio = limpio.substring(5).trim();
  if (limpio.isEmpty) return limpio;
  return limpio[0].toUpperCase() + limpio.substring(1);
}

/// Ficheros por petición (el máximo de `titles` de la API sin permisos
/// especiales es 50).
const int maximoArchivosPorPeticionCommons = 50;

/// Petición de autor y licencia de hasta 50 ficheros.
Uri uriMetadatosCommons(List<String> archivos) {
  return Uri.https('commons.wikimedia.org', '/w/api.php', {
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'prop': 'imageinfo',
    'iiprop': 'extmetadata|url',
    'iiextmetadatafilter': 'Artist|LicenseShortName|LicenseUrl|NonFree|Copyrighted|AttributionRequired',
    'titles': archivos.map((archivo) => 'File:$archivo').join('|'),
  });
}

/// Licencia aceptada a partir del nombre corto de Commons, o null.
LicenciaCommons? licenciaLibreCommons(String? licenciaCorta) {
  if (licenciaCorta == null) return null;
  final normalizada =
      licenciaCorta.toLowerCase().replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizada.isEmpty) return null;
  if (normalizada == 'public domain' ||
      normalizada == 'pd' ||
      normalizada.startsWith('pd-') ||
      normalizada.startsWith('public domain mark')) {
    return LicenciaCommons.dominioPublico;
  }
  if (RegExp(r'^cc0( 1\.0)?( universal)?$').hasMatch(normalizada) || normalizada == 'cc-zero') {
    return LicenciaCommons.cc0;
  }
  // «CC BY 4.0», «CC BY-SA 3.0 de», «CC-BY-SA-2.5», «CC BY-SA 3.0 IGO».
  final coincidencia = RegExp(r'^cc[ -]by(-sa)?(?:[ -]\d(?:\.\d)?)?(?:[ -][a-z]{2,3}(?:-[a-z]{2,4})?)?$')
      .firstMatch(normalizada);
  if (coincidencia == null) return null;
  return coincidencia.group(1) == null ? LicenciaCommons.ccBy : LicenciaCommons.ccBySa;
}

/// Texto plano de un campo HTML de Commons (el autor viene con enlaces):
/// sin etiquetas, con las entidades más comunes y los espacios juntados.
String textoPlanoDeHtml(String html) {
  var texto = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
  texto = texto.replaceAll(RegExp(r'<[^>]*>'), '');
  const entidades = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&#039;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };
  entidades.forEach((entidad, caracter) => texto = texto.replaceAll(entidad, caracter));
  texto = texto.replaceAllMapped(RegExp(r'&#(\d+);'), (coincidencia) {
    final codigo = int.tryParse(coincidencia.group(1)!);
    return codigo == null ? '' : String.fromCharCode(codigo);
  });
  return texto.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Autor más largo que esto se recorta (algunos campos traen párrafos).
const int maximoCaracteresAutor = 80;

String? _valorExt(Map extmetadata, String clave) {
  final campo = extmetadata[clave];
  if (campo is! Map) return null;
  final valor = campo['value'];
  return valor?.toString();
}

/// Metadatos de cada fichero pedido. La clave es el nombre normalizado;
/// el valor, null si no hay licencia libre clara (o falta el fichero, o es
/// CC BY sin autor). Los ficheros que no salen en la respuesta no están.
Map<String, MetadatosFotoCommons?> parsearMetadatosCommons(Map<String, dynamic> json) {
  final resultado = <String, MetadatosFotoCommons?>{};
  final consulta = json['query'];
  if (consulta is! Map) return resultado;
  final paginas = consulta['pages'];
  final listaPaginas = paginas is List
      ? paginas
      : paginas is Map
          ? paginas.values.toList()
          : const [];
  for (final pagina in listaPaginas) {
    if (pagina is! Map) continue;
    final titulo = pagina['title'];
    if (titulo is! String) continue;
    final archivo = normalizarNombreArchivoCommons(titulo);
    resultado[archivo] = _metadatosDePagina(archivo, pagina);
  }
  return resultado;
}

MetadatosFotoCommons? _metadatosDePagina(String archivo, Map pagina) {
  if (pagina['missing'] == true || pagina['missing'] == '') return null;
  final informaciones = pagina['imageinfo'];
  if (informaciones is! List || informaciones.isEmpty || informaciones.first is! Map) return null;
  final informacion = informaciones.first as Map;
  final extmetadata = informacion['extmetadata'];
  if (extmetadata is! Map) return null;
  final noLibre = _valorExt(extmetadata, 'NonFree')?.trim().toLowerCase();
  if (noLibre == 'true' || noLibre == '1') return null;
  final licenciaCorta = _valorExt(extmetadata, 'LicenseShortName');
  final licencia = licenciaLibreCommons(licenciaCorta == null ? null : textoPlanoDeHtml(licenciaCorta));
  if (licencia == null) return null;
  final artista = _valorExt(extmetadata, 'Artist');
  var autor = artista == null ? '' : textoPlanoDeHtml(artista);
  if (autor.length > maximoCaracteresAutor) autor = '${autor.substring(0, maximoCaracteresAutor - 1)}…';
  final sinDerechos = licencia == LicenciaCommons.dominioPublico || licencia == LicenciaCommons.cc0;
  if (autor.isEmpty && !sinDerechos) return null;
  final urlLicencia = _valorExt(extmetadata, 'LicenseUrl');
  final urlDescripcion = informacion['descriptionurl'];
  return MetadatosFotoCommons(
    archivo: archivo,
    autor: autor.isEmpty ? null : autor,
    licencia: licencia,
    licenciaCorta: textoPlanoDeHtml(licenciaCorta!),
    urlLicencia: urlLicencia == null || urlLicencia.isEmpty ? null : _conEsquema(urlLicencia),
    urlDescripcion: urlDescripcion is String ? _conEsquema(urlDescripcion) : null,
  );
}

String _conEsquema(String url) => url.startsWith('//') ? 'https:$url' : url;
