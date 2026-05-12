import 'dart:convert';

import 'package:http/http.dart' as http;

import 'servicio_inaturalist.dart' show buscarTaxones;

/// Resultado unificado de búsqueda en repositorios externos
/// (iNaturalist + Wikipedia Commons). Cada uno trae **suficiente
/// metadata para atribuir** según las licencias CC-BY/CC-BY-SA:
/// autor + URL de origen + licencia legible.
class ResultadoFotoArchivo {
  const ResultadoFotoArchivo({
    required this.thumbnailUrl,
    required this.urlCompleta,
    required this.urlPagina,
    required this.fuente,
    this.autor,
    this.licencia,
    this.titulo,
  });

  /// URL de un thumbnail pequeño (~300-600px) para mostrar en el grid
  /// de selección sin saturar al usuario con la imagen original.
  final String thumbnailUrl;

  /// URL de la imagen original (resolución completa). Es la que se
  /// descarga al disco cuando el usuario selecciona la foto.
  final String urlCompleta;

  /// Página de origen (artículo Commons, observación iNaturalist).
  /// Útil para volver a la fuente y para atribuir formalmente.
  final String urlPagina;

  /// `'wikipedia'` o `'inaturalist'`.
  final String fuente;

  final String? autor;

  /// Licencia normalizada en minúsculas (`'cc-by-4.0'`,
  /// `'cc-by-sa-4.0'`, `'cc0'`, `'public-domain'`). `null` si no se
  /// pudo determinar — en ese caso la foto NO debería ofrecerse al
  /// usuario porque la app no puede garantizar licencia válida.
  final String? licencia;

  final String? titulo;
}

/// Cabeceras User-Agent para las llamadas. Wikipedia y iNaturalist
/// piden identificarse — sin esto pueden bloquear o limitar.
const _cabeceras = {
  'User-Agent':
      'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
  'Accept': 'application/json',
};

/// Conjunto de licencias aceptadas. Sólo aceptamos las que permiten
/// reutilización con atribución (`cc-by`, `cc-by-sa`) o sin
/// requisito (`cc0`, `public-domain`). Código de iNaturalist viene
/// en lowercase con `-`; código de Commons en formato variado se
/// normaliza con [_normalizarLicencia].
const _licenciasAceptadas = {
  'cc-by',
  'cc-by-sa',
  'cc0',
  'public-domain',
};

const _licenciasInaturalistConsulta =
    'cc-by,cc-by-sa,cc0';

/// Busca fotos de archivo en iNaturalist + Wikipedia Commons en
/// paralelo. [consulta] suele ser el nombre científico o nombre
/// común del taxón. Devuelve hasta [limite] resultados por fuente
/// (max 24 totales por defecto).
///
/// Errores de red se tragan por fuente: si iNaturalist falla pero
/// Wikipedia responde, devuelve sólo Wikipedia. Si las dos fallan,
/// devuelve lista vacía sin lanzar — la UI muestra estado vacío.
Future<List<ResultadoFotoArchivo>> buscarFotosDeArchivo(
  String consulta, {
  int limitePorFuente = 12,
}) async {
  final consultaLimpia = consulta.trim();
  if (consultaLimpia.isEmpty) return const [];

  final futuras = await Future.wait([
    _buscarEnInaturalist(consultaLimpia, limite: limitePorFuente)
        .catchError((Object _) => <ResultadoFotoArchivo>[]),
    _buscarEnWikipediaCommons(consultaLimpia, limite: limitePorFuente)
        .catchError((Object _) => <ResultadoFotoArchivo>[]),
  ]);

  return [...futuras[0], ...futuras[1]];
}

// =================================================================
// iNaturalist
// =================================================================

Future<List<ResultadoFotoArchivo>> _buscarEnInaturalist(
  String consulta, {
  required int limite,
}) async {
  // Paso 1: encontrar el taxón. Si no hay match preciso, abortamos
  // — buscar fotos de "fósil bonito que vi" no tiene sentido.
  final taxones = await buscarTaxones(consulta, limite: 1);
  if (taxones.isEmpty) return const [];
  final taxonId = taxones.first.id;

  // Paso 2: pedir observaciones con foto del taxón filtrando por
  // licencia. iNaturalist ordena por `votes` por defecto — las
  // fotos con más votos suelen ser las mejor identificadas.
  final uri = Uri.parse('https://api.inaturalist.org/v1/observations')
      .replace(queryParameters: {
    'taxon_id': taxonId.toString(),
    'photo_license': _licenciasInaturalistConsulta,
    'photos': 'true',
    'quality_grade': 'research',
    'per_page': limite.clamp(1, 30).toString(),
    'order_by': 'votes',
  });

  final respuesta = await http.get(uri, headers: _cabeceras);
  if (respuesta.statusCode != 200) return const [];

  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes))
      as Map<String, dynamic>;
  final observaciones = (cuerpo['results'] as List?) ?? const [];

  final resultados = <ResultadoFotoArchivo>[];
  for (final obsRaw in observaciones) {
    if (obsRaw is! Map) continue;
    final obs = obsRaw.cast<String, Object?>();
    final fotos = (obs['photos'] as List?) ?? const [];
    for (final fotoRaw in fotos) {
      if (fotoRaw is! Map) continue;
      final foto = fotoRaw.cast<String, Object?>();
      final licencia = _normalizarLicencia(foto['license_code'] as String?);
      if (licencia == null) continue;
      final urlSquare = foto['url'] as String?;
      if (urlSquare == null) continue;
      // El campo `url` viene en thumbnail "square" (~75px). Para el
      // thumbnail de UI hacemos el reemplazo a "medium" (~500px), y
      // para la descarga final a "original".
      final thumb = urlSquare.replaceAll('/square.', '/medium.');
      final completa = urlSquare.replaceAll('/square.', '/original.');
      final atribucion = foto['attribution'] as String?;
      final autor = _extraerAutorInaturalist(atribucion);
      final obsId = (obs['id'] as num?)?.toInt();
      resultados.add(ResultadoFotoArchivo(
        thumbnailUrl: thumb,
        urlCompleta: completa,
        urlPagina: obsId == null
            ? 'https://www.inaturalist.org/observations'
            : 'https://www.inaturalist.org/observations/$obsId',
        fuente: 'inaturalist',
        autor: autor,
        licencia: licencia,
      ));
      if (resultados.length >= limite) return resultados;
    }
  }
  return resultados;
}

/// El campo `attribution` de iNaturalist viene como
/// "(c) Name, some rights reserved (CC-BY-SA)". Extraemos el nombre
/// quitando el prefijo "(c) " y el sufijo de licencia.
String? _extraerAutorInaturalist(String? attribution) {
  if (attribution == null || attribution.isEmpty) return null;
  var texto = attribution.replaceFirst(RegExp(r'^\([cC]\)\s*'), '');
  texto = texto.replaceFirst(RegExp(r',\s*(some|all)\s.+$'), '');
  return texto.trim().isEmpty ? null : texto.trim();
}

// =================================================================
// Wikipedia Commons
// =================================================================

Future<List<ResultadoFotoArchivo>> _buscarEnWikipediaCommons(
  String consulta,
  {required int limite}
) async {
  // Buscamos en Commons como en _obtenerGaleriaInterno: por título
  // de página + búsqueda de archivos. Pedimos `extmetadata` para
  // obtener autor + licencia explícita por imagen.
  final uri = Uri.parse('https://commons.wikimedia.org/w/api.php')
      .replace(queryParameters: {
    'action': 'query',
    'format': 'json',
    'generator': 'search',
    'gsrnamespace': '6',
    'gsrlimit': limite.toString(),
    'gsrsearch': consulta,
    'prop': 'imageinfo',
    'iiprop': 'url|extmetadata|user',
    'iiurlwidth': '600',
  });

  final respuesta = await http.get(uri, headers: _cabeceras);
  if (respuesta.statusCode != 200) return const [];

  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes))
      as Map<String, dynamic>;
  final pages = ((cuerpo['query'] as Map?)?['pages'] as Map?) ?? const {};

  final resultados = <ResultadoFotoArchivo>[];
  for (final entradaRaw in pages.values) {
    if (entradaRaw is! Map) continue;
    final entrada = entradaRaw.cast<String, Object?>();
    final infos = (entrada['imageinfo'] as List?) ?? const [];
    if (infos.isEmpty) continue;
    final infoRaw = infos.first;
    if (infoRaw is! Map) continue;
    final info = infoRaw.cast<String, Object?>();

    final extmeta = (info['extmetadata'] as Map?)?.cast<String, Object?>();
    final licencia = _normalizarLicencia(
      _valorExtmeta(extmeta, 'LicenseShortName')?.toLowerCase() ??
          _valorExtmeta(extmeta, 'License'),
    );
    if (licencia == null) continue;

    final completa = info['url'] as String?;
    final thumb = info['thumburl'] as String? ?? completa;
    if (completa == null || thumb == null) continue;
    if (!_extensionImagenAceptada(completa)) continue;

    final tituloPagina = entrada['title'] as String?;
    final autor = _limpiarHtml(_valorExtmeta(extmeta, 'Artist')) ??
        info['user'] as String?;
    final urlPagina = tituloPagina == null
        ? 'https://commons.wikimedia.org'
        : 'https://commons.wikimedia.org/wiki/${Uri.encodeComponent(tituloPagina)}';

    resultados.add(ResultadoFotoArchivo(
      thumbnailUrl: thumb,
      urlCompleta: completa,
      urlPagina: urlPagina,
      fuente: 'wikipedia',
      autor: autor,
      licencia: licencia,
      titulo: tituloPagina,
    ));
  }
  return resultados;
}

String? _valorExtmeta(Map<String, Object?>? extmeta, String clave) {
  if (extmeta == null) return null;
  final entrada = extmeta[clave];
  if (entrada is! Map) return null;
  return entrada['value']?.toString();
}

/// El campo `Artist` de Commons puede venir con HTML
/// (enlaces, spans). Quitamos las etiquetas para obtener un
/// nombre legible. Si queda vacío, devuelve null.
String? _limpiarHtml(String? raw) {
  if (raw == null) return null;
  final sinHtml = raw.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  return sinHtml.isEmpty ? null : sinHtml;
}

bool _extensionImagenAceptada(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.svg') || lower.endsWith('.svg.png')) return false;
  if (lower.contains('.pdf') ||
      lower.contains('.djvu') ||
      lower.contains('.tif')) {
    return false;
  }
  return true;
}

/// Normaliza una licencia heterogénea (Wikipedia Commons usa
/// "CC BY-SA 4.0", iNaturalist usa "cc-by-sa") al formato canónico
/// que la app usa para badges + filtrado. Devuelve `null` si la
/// licencia no es de las aceptadas.
String? _normalizarLicencia(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final texto = raw.toLowerCase().trim();
  final normalizada = texto
      .replaceAll(' ', '-')
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'cc-?'), 'cc-');

  // Mapeo de prefijos a la forma canónica.
  for (final aceptada in _licenciasAceptadas) {
    if (normalizada.startsWith(aceptada)) {
      // Conservamos versión si viene (ej. cc-by-sa-4.0); si no,
      // devolvemos la base.
      final match = RegExp(r'(cc-by-sa|cc-by|cc0)-?(\d+\.?\d*)?')
          .firstMatch(normalizada);
      if (match != null) {
        final base = match.group(1)!;
        final version = match.group(2);
        return version == null ? base : '$base-$version';
      }
      return aceptada;
    }
  }
  // Casos especiales sin prefijo cc-.
  if (normalizada.contains('public-domain') ||
      normalizada == 'pd' ||
      normalizada.contains('publicdomain')) {
    return 'public-domain';
  }
  return null;
}
