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
    final bytesCacheados = await CacheTeselasDisco.leer(url);
    if (bytesCacheados != null && bytesCacheados.isNotEmpty) {
      final buffer = await ImmutableBuffer.fromUint8List(bytesCacheados);
      return decode(buffer);
    }
    final respuesta = await http.get(Uri.parse(url), headers: {'User-Agent': userAgent});
    if (respuesta.statusCode != 200) {
      throw Exception('HTTP ${respuesta.statusCode} para $url');
    }
    final bytes = respuesta.bodyBytes;
    await CacheTeselasDisco.escribir(url, bytes);
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
  TileProviderConCache({this.userAgent = 'naturaleza_flutter'});

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _ImagenDesdeCacheOWeb(url, userAgent);
  }
}
