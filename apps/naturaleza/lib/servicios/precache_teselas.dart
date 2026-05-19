import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'cache_teselas.dart';

class LimitesPrecache {
  final double sur;
  final double norte;
  final double oeste;
  final double este;
  LimitesPrecache({required this.sur, required this.norte, required this.oeste, required this.este});
}

class ConfiguracionCapaPrecache {
  final String nombre;
  final String? urlPlantilla;
  final WMSTileLayerOptions? wmsOpciones;
  ConfiguracionCapaPrecache({required this.nombre, this.urlPlantilla, this.wmsOpciones})
      : assert(urlPlantilla != null || wmsOpciones != null);
}

class ProgresoPrecache {
  final int descargadas;
  final int falladas;
  final int total;
  final int bytesAcumulados;
  ProgresoPrecache(this.descargadas, this.falladas, this.total, this.bytesAcumulados);
}

int _longitudATileX(double longitud, int zoom) =>
    ((longitud + 180) / 360 * (1 << zoom)).floor();

int _latitudATileY(double latitud, int zoom) {
  final radianes = latitud * pi / 180;
  return ((1 - log(tan(radianes) + 1 / cos(radianes)) / pi) / 2 * (1 << zoom)).floor();
}

List<({int x, int y, int z})> _coordenadasParaArea(LimitesPrecache limites, int zoomMin, int zoomMax) {
  final coords = <({int x, int y, int z})>[];
  for (var z = zoomMin; z <= zoomMax; z++) {
    final xMin = _longitudATileX(limites.oeste, z);
    final xMax = _longitudATileX(limites.este, z);
    final yMin = _latitudATileY(limites.norte, z);
    final yMax = _latitudATileY(limites.sur, z);
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        coords.add((x: x, y: y, z: z));
      }
    }
  }
  return coords;
}

({int totalUrls, int teselas, int capas}) calcularResumen({
  required LimitesPrecache limites,
  required int zoomMin,
  required int zoomMax,
  required List<ConfiguracionCapaPrecache> capas,
}) {
  final coords = _coordenadasParaArea(limites, zoomMin, zoomMax);
  return (totalUrls: coords.length * capas.length, teselas: coords.length, capas: capas.length);
}

String _construirUrl(String plantilla, int z, int x, int y) {
  return plantilla.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y');
}

String _construirUrlPara(ConfiguracionCapaPrecache capa, int z, int x, int y) {
  if (capa.wmsOpciones != null) {
    return capa.wmsOpciones!.getUrl(TileCoordinates(x, y, z), 256, false);
  }
  return _construirUrl(capa.urlPlantilla!, z, x, y);
}

Future<void> precachearArea({
  required LimitesPrecache limites,
  required int zoomMin,
  required int zoomMax,
  required List<ConfiguracionCapaPrecache> capas,
  void Function(ProgresoPrecache)? alProgreso,
  int concurrencia = 6,
  String userAgent = 'naturaleza_flutter',
}) async {
  final coords = _coordenadasParaArea(limites, zoomMin, zoomMax);
  final urls = <String>[];
  for (final capa in capas) {
    for (final coord in coords) {
      urls.add(_construirUrlPara(capa, coord.z, coord.x, coord.y));
    }
  }

  var descargadas = 0;
  var falladas = 0;
  var bytes = 0;
  final total = urls.length;

  for (var inicio = 0; inicio < urls.length; inicio += concurrencia) {
    final fin = (inicio + concurrencia).clamp(0, urls.length);
    final lote = urls.sublist(inicio, fin);
    await Future.wait(lote.map((url) async {
      final yaCacheado = await CacheTeselasDisco.leer(url);
      if (yaCacheado != null && yaCacheado.isNotEmpty) {
        descargadas += 1;
        bytes += yaCacheado.length;
        return;
      }
      try {
        final respuesta = await http.get(Uri.parse(url), headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 30));
        if (respuesta.statusCode == 200 && respuesta.bodyBytes.isNotEmpty) {
          await CacheTeselasDisco.escribir(url, respuesta.bodyBytes);
          descargadas += 1;
          bytes += respuesta.bodyBytes.length;
        } else {
          falladas += 1;
        }
      } catch (_) {
        falladas += 1;
      }
    }));
    alProgreso?.call(ProgresoPrecache(descargadas, falladas, total, bytes));
  }
}
