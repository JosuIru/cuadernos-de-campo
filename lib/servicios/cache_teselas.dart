import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show ImmutableBuffer;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

class CacheTeselasDisco {
  static Directory? _directorioCache;

  static Future<Directory> obtenerDirectorio() async {
    if (_directorioCache != null) return _directorioCache!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(path_lib.join(base.path, 'tile_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _directorioCache = dir;
    return dir;
  }

  static String _claveDesdeUrl(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    return hash;
  }

  static Future<File> ficheroParaUrl(String url) async {
    final dir = await obtenerDirectorio();
    return File(path_lib.join(dir.path, '${_claveDesdeUrl(url)}.tile'));
  }

  static Future<Uint8List?> leer(String url) async {
    final fichero = await ficheroParaUrl(url);
    if (await fichero.exists()) {
      try {
        return await fichero.readAsBytes();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> escribir(String url, Uint8List bytes) async {
    final fichero = await ficheroParaUrl(url);
    await fichero.writeAsBytes(bytes, flush: false);
  }

  static Future<int> tamanoTotalBytes() async {
    final dir = await obtenerDirectorio();
    var total = 0;
    await for (final entidad in dir.list()) {
      if (entidad is File) {
        try {
          total += await entidad.length();
        } catch (_) {}
      }
    }
    return total;
  }

  static Future<int> contarFicheros() async {
    final dir = await obtenerDirectorio();
    var total = 0;
    await for (final entidad in dir.list()) {
      if (entidad is File) total += 1;
    }
    return total;
  }

  static Future<void> vaciar() async {
    final dir = await obtenerDirectorio();
    await for (final entidad in dir.list()) {
      if (entidad is File) {
        try {
          await entidad.delete();
        } catch (_) {}
      }
    }
  }

  /// Si la caché supera [maxBytes], borra los ficheros más antiguos
  /// hasta bajar del 80% del límite. Pensado para llamar después de
  /// escribir una tesela nueva — es barato porque sólo actúa cuando
  /// se excede el umbral (~1 de cada N escrituras).
  static Future<void> limpiarSiExcede(int maxBytes) async {
    final dir = await obtenerDirectorio();
    final ficheros = <File>[];
    var total = 0;
    await for (final entidad in dir.list()) {
      if (entidad is File) {
        try {
          final len = await entidad.length();
          total += len;
          ficheros.add(entidad);
        } catch (_) {}
      }
    }
    if (total <= maxBytes) return;
    // Ordenar por fecha de modificación (más antiguo primero)
    ficheros.sort((a, b) {
      try {
        return a.lastModifiedSync().compareTo(b.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });
    final umbral = (maxBytes * 0.8).toInt();
    for (final f in ficheros) {
      if (total <= umbral) break;
      try {
        final len = await f.length();
        await f.delete();
        total -= len;
      } catch (_) {}
    }
  }
}

/// Cache LRU en RAM de teselas. Se consulta antes que la cache de disco para
/// evitar el roundtrip al filesystem en pan/zoom rápido — las mismas teselas
/// se piden múltiples veces cuando el usuario revisita una zona. Tamaño
/// pequeño (256 entradas) para limitar memoria; con 25-50 KB por tesela
/// equivale a 6-12 MB, suficiente para varios viewports.
class _CacheTeselasMemoria {
  static final _CacheTeselasMemoria instancia = _CacheTeselasMemoria._();
  _CacheTeselasMemoria._();

  static const int _maxEntradas = 256;
  final Map<String, Uint8List> _entradas = <String, Uint8List>{};

  Uint8List? leer(String url) {
    final bytes = _entradas.remove(url);
    if (bytes == null) return null;
    _entradas[url] = bytes; // move-to-end → LRU
    return bytes;
  }

  void guardar(String url, Uint8List bytes) {
    _entradas.remove(url);
    _entradas[url] = bytes;
    if (_entradas.length > _maxEntradas) {
      _entradas.remove(_entradas.keys.first);
    }
  }
}

class _ImagenDesdeCacheOWeb extends ImageProvider<_ImagenDesdeCacheOWeb> {
  final String url;
  final String userAgent;
  const _ImagenDesdeCacheOWeb(this.url, this.userAgent);

  @override
  Future<_ImagenDesdeCacheOWeb> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }

  @override
  ImageStreamCompleter loadImage(_ImagenDesdeCacheOWeb key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _cargarCodec(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _cargarCodec(ImageDecoderCallback decode) async {
    final bytesRam = _CacheTeselasMemoria.instancia.leer(url);
    if (bytesRam != null) {
      final buffer = await ImmutableBuffer.fromUint8List(bytesRam);
      return decode(buffer);
    }
    final bytesCacheados = await CacheTeselasDisco.leer(url);
    if (bytesCacheados != null && bytesCacheados.isNotEmpty) {
      _CacheTeselasMemoria.instancia.guardar(url, bytesCacheados);
      final buffer = await ImmutableBuffer.fromUint8List(bytesCacheados);
      return decode(buffer);
    }
    final respuesta = await http.get(Uri.parse(url), headers: {'User-Agent': userAgent});
    if (respuesta.statusCode != 200) {
      throw Exception('HTTP ${respuesta.statusCode} para $url');
    }
    final bytes = respuesta.bodyBytes;
    _CacheTeselasMemoria.instancia.guardar(url, bytes);
    await CacheTeselasDisco.escribir(url, bytes);
    // Poda silenciosa si la caché crece demasiado (200 MB)
    unawaited(CacheTeselasDisco.limpiarSiExcede(200 * 1024 * 1024));
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) => other is _ImagenDesdeCacheOWeb && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class TileProviderConCache extends TileProvider {
  final String userAgent;
  TileProviderConCache({this.userAgent = 'fosiles_flutter'});

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _ImagenDesdeCacheOWeb(url, userAgent);
  }
}
