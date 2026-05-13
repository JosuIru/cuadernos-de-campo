import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

const urlWmsIgmeGeode =
    'https://mapas.igme.es/gis/services/Cartografia_Geologica/IGME_Geode_50/MapServer/WMSServer';

const urlWmsIgmeMagna =
    'https://mapas.igme.es/gis/services/Cartografia_Geologica/IGME_MAGNA_50/MapServer/WMSServer';

const urlWmsIgmeEdades1M =
    'https://mapas.igme.es/gis/services/Cartografia_Geologica/IGME_Edades_1M/MapServer/WMSServer';

const urlWmsIgmeLitologias1M =
    'https://mapas.igme.es/gis/services/Cartografia_Geologica/IGME_Litologias_1M/MapServer/WMSServer';

const urlWmsIgmeLig =
    'https://mapas.igme.es/gis/services/BasesDatos/IGME_IELIG/MapServer/WMSServer';

class CapaGeologicaWms {
  final String nombre;
  final String urlBase;
  final List<String> capas;
  const CapaGeologicaWms({required this.nombre, required this.urlBase, required this.capas});
}

const List<CapaGeologicaWms> capasGeologicasWms = [
  CapaGeologicaWms(nombre: 'MAGNA 50', urlBase: urlWmsIgmeMagna, capas: ['0']),
  CapaGeologicaWms(nombre: 'GEODE 50', urlBase: urlWmsIgmeGeode, capas: ['0']),
  CapaGeologicaWms(nombre: 'Edades 1M', urlBase: urlWmsIgmeEdades1M, capas: ['0']),
  CapaGeologicaWms(nombre: 'Litologías 1M', urlBase: urlWmsIgmeLitologias1M, capas: ['0']),
];

class ContextoGeologico {
  final String? edad;
  final String? formacion;
  final String? litologia;
  final String? zona;
  final Map<String, dynamic> crudo;
  ContextoGeologico({this.edad, this.formacion, this.litologia, this.zona, required this.crudo});

  Map<String, dynamic> toJson() => {
        'edad': edad,
        'formacion': formacion,
        'litologia': litologia,
        'zona': zona,
        'crudo': crudo,
      };
}

String _claveGeologia(double latitud, double longitud) =>
    '${latitud.toStringAsFixed(3)},${longitud.toStringAsFixed(3)}';

/// Caché LRU en memoria de respuestas IGME ya consultadas (con su clave
/// redondeada a 3 decimales ≈ 111 m). Evita el ida-y-vuelta al disco
/// cuando el usuario pasea por una zona ya explorada con el asistente
/// activo, o cuando vuelve a tocar un punto que ya miró antes. Capacidad
/// 200 entradas (~50 KB de RAM como mucho).
class _CacheGeologiaMemoria {
  static const int _maxEntradas = 200;
  static final Map<String, ContextoGeologico?> _entradas = <String, ContextoGeologico?>{};

  static ContextoGeologico? leer(String clave, {required bool sentinel}) {
    if (!_entradas.containsKey(clave)) return null;
    final valor = _entradas.remove(clave);
    _entradas[clave] = valor; // re-insertar para marcar como reciente
    return valor;
  }

  static bool contiene(String clave) => _entradas.containsKey(clave);

  static void guardar(String clave, ContextoGeologico? valor) {
    _entradas[clave] = valor;
    if (_entradas.length > _maxEntradas) {
      _entradas.remove(_entradas.keys.first);
    }
  }
}

Future<ContextoGeologico?> _leerCacheGeologia(String clave) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fichero = File(path_lib.join(dir.path, 'geologia_cache', '$clave.json'));
    if (await fichero.exists()) {
      final json = jsonDecode(await fichero.readAsString()) as Map<String, dynamic>;
      return ContextoGeologico(
        edad: json['e'] as String?,
        formacion: json['f'] as String?,
        litologia: json['l'] as String?,
        zona: json['z'] as String?,
        crudo: (json['c'] as Map<String, dynamic>?) ?? {},
      );
    }
  } catch (_) {}
  return null;
}

Future<void> _escribirCacheGeologia(String clave, ContextoGeologico ctx) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final subdir = Directory(path_lib.join(dir.path, 'geologia_cache'));
    if (!await subdir.exists()) await subdir.create(recursive: true);
    final fichero = File(path_lib.join(subdir.path, '$clave.json'));
    await fichero.writeAsString(jsonEncode({
      'e': ctx.edad,
      'f': ctx.formacion,
      'l': ctx.litologia,
      'z': ctx.zona,
      'c': ctx.crudo,
    }));
  } catch (_) {}
}

Future<ContextoGeologico?> consultarContextoGeologico(double latitud, double longitud) async {
  final clave = _claveGeologia(latitud, longitud);
  // 1. Caché en memoria (incluye respuestas "sin datos" para no repreguntar)
  if (_CacheGeologiaMemoria.contiene(clave)) {
    return _CacheGeologiaMemoria.leer(clave, sentinel: true);
  }
  // 2. Caché en disco
  final cache = await _leerCacheGeologia(clave);
  if (cache != null) {
    _CacheGeologiaMemoria.guardar(clave, cache);
    return cache;
  }
  // 3. Red con reintentos
  const intentos = 3;
  for (var i = 0; i < intentos; i++) {
    final resultado = await _intentarConsultarGeode(latitud, longitud);
    if (resultado.exitoEfectivo) {
      if (resultado.contexto != null) {
        await _escribirCacheGeologia(clave, resultado.contexto!);
      }
      _CacheGeologiaMemoria.guardar(clave, resultado.contexto);
      return resultado.contexto;
    }
    if (i < intentos - 1) {
      await Future.delayed(Duration(seconds: 1 << i));
    }
  }
  return null;
}

class _ResultadoConsultaGeode {
  final ContextoGeologico? contexto;
  final bool sinDatos;
  final bool fallo;
  _ResultadoConsultaGeode.conContexto(this.contexto) : sinDatos = false, fallo = false;
  _ResultadoConsultaGeode.sinDatosLegitimo() : contexto = null, sinDatos = true, fallo = false;
  _ResultadoConsultaGeode.error() : contexto = null, sinDatos = false, fallo = true;
  bool get exitoEfectivo => !fallo;
}

Future<_ResultadoConsultaGeode> _intentarConsultarGeode(double latitud, double longitud) async {
  final delta = 0.0005;
  final bbox = '${longitud - delta},${latitud - delta},${longitud + delta},${latitud + delta}';
  final params = <String, String>{
    'service': 'WMS',
    'version': '1.1.1',
    'request': 'GetFeatureInfo',
    'layers': '1',
    'query_layers': '1',
    'styles': '',
    'bbox': bbox,
    'srs': 'EPSG:4326',
    'width': '101',
    'height': '101',
    'x': '50',
    'y': '50',
    'format': 'image/png',
    'info_format': 'application/geo+json',
    'feature_count': '5',
  };
  final uri = Uri.parse(urlWmsIgmeGeode).replace(queryParameters: params);
  try {
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 12));
    if (respuesta.statusCode >= 500 || respuesta.statusCode == 408 || respuesta.statusCode == 429) {
      return _ResultadoConsultaGeode.error();
    }
    if (respuesta.statusCode != 200) return _ResultadoConsultaGeode.sinDatosLegitimo();
    final cuerpo = utf8.decode(respuesta.bodyBytes);
    if (!cuerpo.trim().startsWith('{')) return _ResultadoConsultaGeode.error();
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    final features = (json['features'] as List?) ?? const [];
    if (features.isEmpty) return _ResultadoConsultaGeode.sinDatosLegitimo();
    final propiedades = (features.first['properties'] as Map).cast<String, dynamic>();
    return _ResultadoConsultaGeode.conContexto(interpretarPropiedadesGeode(propiedades));
  } catch (_) {
    return _ResultadoConsultaGeode.error();
  }
}

ContextoGeologico interpretarPropiedadesGeode(Map<String, dynamic> propiedades) {
  String? lookup(List<String> claves) {
    for (final clave in claves) {
      for (final key in propiedades.keys) {
        if (key.toLowerCase() == clave.toLowerCase()) {
          final valor = propiedades[key];
          if (valor != null && valor.toString().trim().isNotEmpty) return valor.toString().trim();
        }
      }
    }
    return null;
  }

  final edadInferior = lookup(['Edad Inferior', 'EDAD_INFERIOR', 'EdadInferior']);
  final edadSuperior = lookup(['Edad Superior', 'EDAD_SUPERIOR', 'EdadSuperior']);
  final descripcion = lookup(['Descripción Unidad Geológica', 'DESCRIPCION', 'Descripcion']);
  final formacion = lookup(['Formacion', 'FORMACION', 'Unidad', 'UNIDAD']);
  final litologia = lookup(['Litologia', 'LITOLOGIA', 'LITOLOGÍA']);

  String? edad;
  if (edadInferior != null && edadSuperior != null && edadInferior != edadSuperior) {
    edad = '$edadInferior – $edadSuperior';
  } else {
    edad = edadSuperior ?? edadInferior;
  }

  return ContextoGeologico(
    edad: edad,
    formacion: formacion,
    litologia: descripcion ?? litologia,
    zona: lookup(['Zona', 'ZONA']),
    crudo: propiedades,
  );
}

class LugarInteresGeologico {
  final String nombre;
  final double latitud;
  final double longitud;
  final String? descripcion;
  final String? interesPrincipal;
  final String? edad;
  final Map<String, dynamic> crudo;
  LugarInteresGeologico({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.descripcion,
    this.interesPrincipal,
    this.edad,
    required this.crudo,
  });
}

Future<List<LugarInteresGeologico>> buscarLigsEnExtension({
  required double sur,
  required double norte,
  required double oeste,
  required double este,
}) async {
  final params = <String, String>{
    'service': 'WMS',
    'version': '1.1.1',
    'request': 'GetFeatureInfo',
    'layers': '0',
    'query_layers': '0',
    'styles': '',
    'bbox': '$oeste,$sur,$este,$norte',
    'srs': 'EPSG:4326',
    'width': '512',
    'height': '512',
    'x': '256',
    'y': '256',
    'format': 'image/png',
    'info_format': 'application/geo+json',
    'feature_count': '50',
  };
  final uri = Uri.parse(urlWmsIgmeLig).replace(queryParameters: params);
  try {
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 15));
    if (respuesta.statusCode != 200) return const [];
    final cuerpo = utf8.decode(respuesta.bodyBytes);
    if (!cuerpo.trim().startsWith('{')) return const [];
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    final features = (json['features'] as List?) ?? const [];
    return features.map((f) {
      final props = ((f['properties'] as Map?) ?? const {}).cast<String, dynamic>();
      final geom = (f['geometry'] as Map?)?.cast<String, dynamic>();
      double lat = 0, lon = 0;
      if (geom != null && geom['coordinates'] is List) {
        final coords = geom['coordinates'] as List;
        if (coords.length >= 2) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }
      String? lookup(List<String> claves) {
        for (final c in claves) {
          for (final k in props.keys) {
            if (k.toLowerCase() == c.toLowerCase()) {
              final v = props[k];
              if (v != null && v.toString().trim().isNotEmpty && v.toString() != 'Null') return v.toString().trim();
            }
          }
        }
        return null;
      }
      return LugarInteresGeologico(
        nombre: lookup(['Nombre', 'NOMBRE', 'Denominación', 'DENOMINACION']) ?? 'LIG sin nombre',
        latitud: lat,
        longitud: lon,
        descripcion: lookup(['Descripción', 'DESCRIPCION', 'Descripcion']),
        interesPrincipal: lookup(['Interés principal', 'INTERES_PRINCIPAL', 'Interés', 'INTERES']),
        edad: lookup(['Edad', 'EDAD', 'Edad geológica']),
        crudo: props,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}
