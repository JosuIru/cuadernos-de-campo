import 'dart:async';
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

const _cabecerasWiki = {'User-Agent': 'fosiles-flutter/1.0 (https://github.com/josu/fosiles-flutter)'};

class _SemaforoWiki {
  final int maxConcurrentes;
  int _activos = 0;
  final List<Completer<void>> _esperando = [];
  _SemaforoWiki(this.maxConcurrentes);

  Future<T> ejecutar<T>(Future<T> Function() tarea) async {
    if (_activos >= maxConcurrentes) {
      final c = Completer<void>();
      _esperando.add(c);
      await c.future;
    }
    _activos++;
    try {
      return await tarea();
    } finally {
      _activos--;
      if (_esperando.isNotEmpty) _esperando.removeAt(0).complete();
    }
  }
}

final _semaforoWiki = _SemaforoWiki(3);

Future<http.Response> _getWiki(Uri uri, {Duration timeout = const Duration(seconds: 10)}) {
  return _semaforoWiki.ejecutar(() => http.get(uri, headers: _cabecerasWiki).timeout(timeout));
}

Future<ResumenWikipedia?> obtenerResumenWikipedia(String titulo, {List<String> idiomas = const ['es', 'en']}) async {
  final clave = '$titulo|${idiomas.join(",")}';
  // 1. Memoria
  final cached = _cacheResumenes[clave];
  if (cached != null) {
    final res = await cached;
    if (res != null) return res;
    _cacheResumenes.remove(clave);
  }
  // 2. Disco (carga asíncrona si aún no está)
  final disco = await _leerDeDisco(clave);
  // 3. Red — si falla, devolvemos lo que tengamos en disco
  final futuro = _obtenerResumenInterno(titulo, idiomas);
  _cacheResumenes[clave] = futuro;
  try {
    final resultado = await futuro;
    if (resultado != null) {
      await _escribirADisco(clave, resultado);
      return resultado;
    }
    _cacheResumenes.remove(clave);
    return disco; // red dice null, devolvemos disco si había
  } catch (_) {
    _cacheResumenes.remove(clave);
    return disco; // sin red: fallback a disco
  }
}

Future<List<String>> obtenerGaleriaWikipedia(String titulo, {List<String> idiomas = const ['es', 'en', 'fr']}) async {
  final clave = 'gal|$titulo|${idiomas.join(",")}';
  // 1. Memoria
  final cached = _cacheGalerias[clave];
  if (cached != null) {
    final lista = await cached;
    if (lista.isNotEmpty) return lista;
    _cacheGalerias.remove(clave);
  }
  // 2. Disco
  final discoUrls = await _leerGaleriaDeDisco(clave);
  // 3. Red
  final futuro = _obtenerGaleriaInterno(titulo, idiomas);
  _cacheGalerias[clave] = futuro;
  try {
    final resultado = await futuro;
    if (resultado.isNotEmpty) {
      await _escribirGaleriaADisco(clave, resultado);
      return resultado;
    }
    _cacheGalerias.remove(clave);
    return discoUrls;
  } catch (_) {
    _cacheGalerias.remove(clave);
    return discoUrls;
  }
}

Future<List<String>> _leerGaleriaDeDisco(String clave) async {
  final disco = await _cargarCacheDisco();
  final entrada = disco['gal:$clave'];
  if (entrada is List) {
    return entrada.cast<String>();
  }
  return const [];
}

Future<void> _escribirGaleriaADisco(String clave, List<String> urls) async {
  final disco = await _cargarCacheDisco();
  disco['gal:$clave'] = urls;
  await _guardarCacheDisco();
}

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
  'User-Agent': 'fosiles-flutter/1.0 (https://github.com/josu/fosiles-flutter)',
};

Future<List<String>> _obtenerGaleriaInterno(String titulo, List<String> idiomas) async {
  final urls = <String>{};
  for (final idioma in idiomas) {
    try {
      final uri = Uri.parse('https://$idioma.wikipedia.org/api/rest_v1/page/media-list/${Uri.encodeComponent(titulo)}');
      final respuesta = await _getWiki(uri);
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
      final respuesta = await _getWiki(uri);
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
      final respuesta = await _getWiki(uri);
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

Future<ResumenWikipedia?> _obtenerResumenInterno(String titulo, List<String> idiomas) async {
  // Recorre todos los idiomas y devuelve el primero **con miniatura**
  // disponible. Si ninguno la tiene, devuelve el primero que existió
  // como artículo (preserva extracto y enlace aunque no haya foto).
  // Esto evita el caso típico: artículo existe en español sin imagen
  // (Trigonia, Ámbar, Jaspe) pero la versión inglesa sí la tiene.
  ResumenWikipedia? primero;
  for (final idioma in idiomas) {
    try {
      final uri = Uri.parse('https://$idioma.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(titulo)}');
      final respuesta = await _getWiki(uri);
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
