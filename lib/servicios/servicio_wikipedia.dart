import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResumenWikipedia {
  final String? thumbnailUrl;
  final String? imagenOriginalUrl;
  final String? extracto;
  final String? enlacePagina;
  final String idioma;
  ResumenWikipedia({this.thumbnailUrl, this.imagenOriginalUrl, this.extracto, this.enlacePagina, required this.idioma});
}

final Map<String, Future<ResumenWikipedia?>> _cacheResumenes = {};
final Map<String, Future<List<String>>> _cacheGalerias = {};

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
  final cached = _cacheResumenes[clave];
  if (cached != null) {
    final res = await cached;
    if (res != null) return res;
    _cacheResumenes.remove(clave);
  }
  final futuro = _obtenerResumenInterno(titulo, idiomas);
  _cacheResumenes[clave] = futuro;
  final resultado = await futuro;
  if (resultado == null) _cacheResumenes.remove(clave);
  return resultado;
}

Future<List<String>> obtenerGaleriaWikipedia(String titulo, {List<String> idiomas = const ['es', 'en', 'fr']}) async {
  final clave = 'gal|$titulo|${idiomas.join(",")}';
  final cached = _cacheGalerias[clave];
  if (cached != null) {
    final lista = await cached;
    if (lista.isNotEmpty) return lista;
    _cacheGalerias.remove(clave);
  }
  final futuro = _obtenerGaleriaInterno(titulo, idiomas);
  _cacheGalerias[clave] = futuro;
  final resultado = await futuro;
  if (resultado.isEmpty) _cacheGalerias.remove(clave);
  return resultado;
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
      return ResumenWikipedia(
        thumbnailUrl: thumb?['source'] as String?,
        imagenOriginalUrl: orig?['source'] as String?,
        extracto: json['extract'] as String?,
        enlacePagina: desktop?['page'] as String?,
        idioma: idioma,
      );
    } catch (_) {
      continue;
    }
  }
  return null;
}
