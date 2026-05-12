import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

class ResumenWikipedia {
  final String? thumbnailUrl;
  final String? imagenOriginalUrl;
  final String? extracto;
  final String? enlacePagina;
  final String idioma;
  ResumenWikipedia({this.thumbnailUrl, this.imagenOriginalUrl, this.extracto, this.enlacePagina, required this.idioma});

  Map<String, dynamic> toJson() => {
        't': thumbnailUrl,
        'o': imagenOriginalUrl,
        'e': extracto,
        'p': enlacePagina,
        'i': idioma,
      };

  factory ResumenWikipedia.fromJson(Map<String, dynamic> json) => ResumenWikipedia(
        thumbnailUrl: json['t'] as String?,
        imagenOriginalUrl: json['o'] as String?,
        extracto: json['e'] as String?,
        enlacePagina: json['p'] as String?,
        idioma: (json['i'] as String?) ?? 'es',
      );
}

final Map<String, Future<ResumenWikipedia?>> _cacheResumenes = {};
final Map<String, Future<List<String>>> _cacheGalerias = {};
Map<String, dynamic>? _discoResumenes;
bool _discoCargado = false;

Future<Map<String, dynamic>> _cargarCacheDisco() async {
  if (_discoCargado && _discoResumenes != null) return _discoResumenes!;
  _discoCargado = true;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fichero = File(path_lib.join(dir.path, 'wiki_cache.json'));
    if (await fichero.exists()) {
      final contenido = await fichero.readAsString();
      _discoResumenes = jsonDecode(contenido) as Map<String, dynamic>;
      return _discoResumenes!;
    }
  } catch (_) {}
  _discoResumenes = {};
  return _discoResumenes!;
}

Future<void> _guardarCacheDisco() async {
  if (_discoResumenes == null) return;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fichero = File(path_lib.join(dir.path, 'wiki_cache.json'));
    await fichero.writeAsString(jsonEncode(_discoResumenes));
  } catch (_) {}
}

Future<ResumenWikipedia?> _leerDeDisco(String clave) async {
  final disco = await _cargarCacheDisco();
  final entrada = disco[clave];
  if (entrada is Map<String, dynamic>) {
    try {
      return ResumenWikipedia.fromJson(entrada);
    } catch (_) {
      disco.remove(clave);
    }
  }
  return null;
}

Future<void> _escribirADisco(String clave, ResumenWikipedia resumen) async {
  final disco = await _cargarCacheDisco();
  disco[clave] = resumen.toJson();
  await _guardarCacheDisco();
}

Future<List<String>> _leerGaleriaDeDisco(String clave) async {
  final disco = await _cargarCacheDisco();
  final entrada = disco['gal:$clave'];
  if (entrada is List) return entrada.cast<String>();
  return const [];
}

Future<void> _escribirGaleriaADisco(String clave, List<String> urls) async {
  final disco = await _cargarCacheDisco();
  disco['gal:$clave'] = urls;
  await _guardarCacheDisco();
}

Future<ResumenWikipedia?> obtenerResumenWikipedia(String titulo, {List<String> idiomas = const ['es', 'en']}) async {
  final clave = '$titulo|${idiomas.join(",")}';
  final futuroExistente = _cacheResumenes[clave];
  if (futuroExistente != null) return futuroExistente;
  // Disco como fallback previo a red
  final disco = await _leerDeDisco(clave);
  final futuroNuevo = _obtenerResumenInterno(titulo, idiomas);
  _cacheResumenes[clave] = futuroNuevo;
  futuroNuevo.then((resumen) {
    if (resumen != null) {
      _escribirADisco(clave, resumen);
    } else {
      _cacheResumenes.remove(clave);
    }
  }).catchError((_) {
    _cacheResumenes.remove(clave);
  });
  try {
    final resultado = await futuroNuevo;
    return resultado ?? disco;
  } catch (_) {
    _cacheResumenes.remove(clave);
    return disco;
  }
}

Future<List<String>> obtenerGaleriaWikipedia(String titulo, {List<String> idiomas = const ['es', 'en', 'fr']}) async {
  final clave = 'gal|$titulo|${idiomas.join(",")}';
  final futuroExistente = _cacheGalerias[clave];
  if (futuroExistente != null) return futuroExistente;
  final discoUrls = await _leerGaleriaDeDisco(clave);
  final futuroNuevo = _obtenerGaleriaInterno(titulo, idiomas);
  _cacheGalerias[clave] = futuroNuevo;
  futuroNuevo.then((urls) {
    if (urls.isNotEmpty) {
      _escribirGaleriaADisco(clave, urls);
    } else {
      _cacheGalerias.remove(clave);
    }
  }).catchError((_) {
    _cacheGalerias.remove(clave);
  });
  try {
    final resultado = await futuroNuevo;
    return resultado.isNotEmpty ? resultado : discoUrls;
  } catch (_) {
    _cacheGalerias.remove(clave);
    return discoUrls;
  }
}

const _cabecerasWiki = {'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)'};

bool _imagenValida(String src) {
  final lower = src.toLowerCase();
  if (lower.endsWith('.svg') || lower.endsWith('.svg.png')) return false;
  if (lower.contains('.pdf') || lower.contains('.djvu') || lower.contains('.tif')) return false;
  if (lower.contains('commons-logo') || lower.contains('wiktionary') || lower.contains('wikispecies-logo')) return false;
  return true;
}

final _reOriginalCommons = RegExp(r'^https?://upload\.wikimedia\.org/wikipedia/commons/([0-9a-f])/([0-9a-f]{2})/([^/]+)$');

String normalizarUrlImagenWiki(String url) {
  if (url.contains('/thumb/')) return url;
  final m = _reOriginalCommons.firstMatch(url);
  if (m == null) return url;
  final h1 = m.group(1)!;
  final h2 = m.group(2)!;
  final archivo = m.group(3)!;
  return 'https://upload.wikimedia.org/wikipedia/commons/thumb/$h1/$h2/$archivo/600px-$archivo';
}

const Map<String, String> cabecerasImagenWiki = {
  'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
};

Future<List<String>> _obtenerGaleriaInterno(String titulo, List<String> idiomas) async {
  final urls = <String>{};
  for (final idioma in idiomas) {
    try {
      final uri = Uri.parse('https://$idioma.wikipedia.org/api/rest_v1/page/media-list/${Uri.encodeComponent(titulo)}');
      final respuesta = await http.get(uri, headers: _cabecerasWiki).timeout(const Duration(seconds: 10));
      if (respuesta.statusCode != 200) continue;
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
      final items = (json['items'] as List?) ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        if (raw['type'] != 'image') continue;
        if (raw['showInGallery'] == false) continue;
        final srcset = (raw['srcset'] as List?) ?? const [];
        if (srcset.isEmpty) continue;
        final src = (srcset.first as Map?)?['src']?.toString() ?? '';
        if (src.isEmpty || !_imagenValida(src)) continue;
        final completa = src.startsWith('//') ? 'https:$src' : src;
        urls.add(completa);
      }
    } catch (_) {
      continue;
    }
  }
  for (final idioma in idiomas) {
    try {
      final uri = Uri.parse(
        'https://$idioma.wikipedia.org/w/api.php'
        '?action=query&prop=pageimages&format=json&pithumbsize=600&redirects=1'
        '&titles=${Uri.encodeComponent(titulo)}',
      );
      final respuesta = await http.get(uri, headers: _cabecerasWiki).timeout(const Duration(seconds: 10));
      if (respuesta.statusCode != 200) continue;
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
      final pages = ((json['query'] as Map?)?['pages'] as Map?) ?? const {};
      for (final entrada in pages.values) {
        if (entrada is! Map) continue;
        final thumb = entrada['thumbnail'];
        if (thumb is Map) {
          final src = thumb['source']?.toString() ?? '';
          if (src.isNotEmpty && _imagenValida(src)) urls.add(src);
        }
      }
      if (urls.isNotEmpty) break;
    } catch (_) {
      continue;
    }
  }
  if (urls.isEmpty) {
    final resumen = await obtenerResumenWikipedia(titulo, idiomas: idiomas);
    final fallback = resumen?.imagenOriginalUrl ?? resumen?.thumbnailUrl;
    if (fallback != null) urls.add(fallback);
  }
  if (urls.isEmpty) {
    try {
      final consulta = titulo.replaceAll('_', ' ');
      final uri = Uri.parse(
        'https://commons.wikimedia.org/w/api.php'
        '?action=query&format=json&generator=search&gsrnamespace=6&gsrlimit=4'
        '&prop=imageinfo&iiprop=url&iiurlwidth=600'
        '&gsrsearch=${Uri.encodeComponent(consulta)}',
      );
      final respuesta = await http.get(uri, headers: _cabecerasWiki).timeout(const Duration(seconds: 10));
      if (respuesta.statusCode == 200) {
        final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
        final pages = ((json['query'] as Map?)?['pages'] as Map?) ?? const {};
        for (final entrada in pages.values) {
          if (entrada is! Map) continue;
          final infos = (entrada['imageinfo'] as List?) ?? const [];
          for (final info in infos) {
            if (info is! Map) continue;
            final src = (info['thumburl'] ?? info['url'])?.toString() ?? '';
            if (src.isNotEmpty && _imagenValida(src)) urls.add(src);
          }
        }
      }
    } catch (_) {}
  }
  final normalizadas = <String>{};
  for (final u in urls) {
    normalizadas.add(normalizarUrlImagenWiki(u));
  }
  return normalizadas.toList();
}

/// Atajo para obtener sólo la miniatura de un artículo de Wikipedia.
/// Es la imagen oficial de la entrada — coincide con el taxón
/// porque el título es el del artículo, no una búsqueda libre. Por
/// eso la guía la prefiere a la de iNaturalist (que matcheaba mal y
/// devolvía tucanes por urracas, ranas por salamandras, etc.).
///
/// Filtra thumbnails que parecen **mapas de distribución** (palabras
/// 'range', 'map', 'distribution', 'mapa', 'distribucion' en la URL).
/// Para taxones como el barbo ibérico o la anguila europea, Wikipedia
/// pone como lead un mapa, no una foto del animal — devolverlo era
/// peor que devolver null porque tapaba el fallback de iNaturalist.
Future<String?> miniaturaPorTituloWikipedia(String tituloWikipedia) async {
  if (tituloWikipedia.trim().isEmpty) return null;
  // Si la versión ES devuelve un mapa de distribución (caso típico
  // del barbo, anguila), forzamos un segundo intento sólo contra EN
  // para escapar del cache positivo del summary ES.
  for (final idiomas in const [['es', 'en'], ['en']]) {
    final resumen = await obtenerResumenWikipedia(tituloWikipedia, idiomas: idiomas);
    final candidata = resumen?.thumbnailUrl ?? resumen?.imagenOriginalUrl;
    if (candidata == null) continue;
    if (_pareceMapaDistribucion(candidata)) continue;
    return candidata;
  }
  return null;
}

bool _pareceMapaDistribucion(String url) {
  final lower = url.toLowerCase();
  const indicios = [
    'range_map',
    'rangemap',
    'distribution_map',
    'distribution.png',
    'distribución',
    'distribucion',
    'mapa_de_distribuc',
    '_range_',
    '_range.',
    '_map_',
    '_map.',
    'leefgebied',
  ];
  for (final indicio in indicios) {
    if (lower.contains(indicio)) return true;
  }
  return false;
}

Future<ResumenWikipedia?> _obtenerResumenInterno(String titulo, List<String> idiomas) async {
  // Recorre todos los idiomas y devuelve el primero **con miniatura**
  // disponible. Si ninguno la tiene, devuelve el primero que existió
  // como artículo (preserva extracto y enlace aunque no haya foto).
  // Esto evita el caso típico: artículo existe en español sin imagen
  // pero la versión inglesa sí la tiene.
  ResumenWikipedia? primero;
  for (final idioma in idiomas) {
    try {
      final uri = Uri.parse('https://$idioma.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(titulo)}');
      final respuesta = await http.get(uri).timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) continue;
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
      final thumb = json['thumbnail'] as Map<String, dynamic>?;
      final orig = json['originalimage'] as Map<String, dynamic>?;
      final paginas = json['content_urls'] as Map<String, dynamic>?;
      final desktop = paginas?['desktop'] as Map<String, dynamic>?;
      final resumen = ResumenWikipedia(
        thumbnailUrl: thumb?['source'] as String?,
        imagenOriginalUrl: orig?['source'] as String?,
        extracto: json['extract'] as String?,
        enlacePagina: desktop?['page'] as String?,
        idioma: idioma,
      );
      if (resumen.thumbnailUrl != null || resumen.imagenOriginalUrl != null) {
        return resumen;
      }
      primero ??= resumen;
    } catch (_) {
      continue;
    }
  }
  return primero;
}
