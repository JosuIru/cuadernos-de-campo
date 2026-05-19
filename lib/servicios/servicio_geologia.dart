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
  /// Frase corta que explica qué pinta esta capa y para qué sirve.
  /// Aparece bajo el nombre en el desplegable de capas del mapa y en la
  /// sección "Sobre la app" en Ajustes, para que el usuario sepa qué
  /// está pintando sin tener que ir probando.
  final String descripcion;
  final String urlBase;
  final List<String> capas;
  /// Índices de capas que se interrogan con WMS GetFeatureInfo al pinchar
  /// un punto. En GEODE 50 la capa visual coloreada (`0` = Zonas) NO
  /// coincide con la capa que lleva los atributos del estrato real
  /// (`1` = Recintos geología); además la capa `3` (Cuaternario -
  /// Recintos) añade detalle del depósito (aluvial, coluvial, glaciar,
  /// eólico, kárstico) cuando hay cobertura cuaternaria. Para que la
  /// respuesta cuadre con lo pintado renderizamos Recintos y consultamos
  /// ambas capas a la vez; la respuesta multi-feature se fusiona dando
  /// prioridad a las capas más específicas (Cuaternario gana sobre
  /// Recintos generales). En MAGNA y los servicios 1M la capa con datos
  /// es la `0`.
  final List<int> capasConsulta;
  const CapaGeologicaWms({
    required this.nombre,
    required this.descripcion,
    required this.urlBase,
    required this.capas,
    this.capasConsulta = const [0],
  });
}

const List<CapaGeologicaWms> capasGeologicasWms = [
  CapaGeologicaWms(
    nombre: 'GEODE 50',
    descripcion: 'Recomendada · continuo geológico nacional. Cada polígono lleva edad, formación y litología; lo que ves y lo que la app sugiere para fósiles van siempre coordinados.',
    urlBase: urlWmsIgmeGeode,
    capas: ['1'],
    capasConsulta: [1, 3],
  ),
  CapaGeologicaWms(
    nombre: 'MAGNA 50',
    descripcion: 'Color por litología (tipo de roca: caliza, arcilla, granito…). Máximo detalle 1:50.000. Útil para "qué tipo de roca piso", NO para ver edades de un vistazo.',
    urlBase: urlWmsIgmeMagna,
    capas: ['0'],
    capasConsulta: [0],
  ),
  CapaGeologicaWms(
    nombre: 'Edades 1M',
    descripcion: 'Color directo por edad geológica (era/período). Lo mejor para ver eras de un vistazo. Resolución 1:1.000.000 — más baja, sirve para escala regional.',
    urlBase: urlWmsIgmeEdades1M,
    capas: ['0'],
    capasConsulta: [0],
  ),
  CapaGeologicaWms(
    nombre: 'Litologías 1M',
    descripcion: 'Litología general (versión simplificada de MAGNA). Resolución 1:1.000.000. Para escala regional cuando MAGNA está demasiado denso.',
    urlBase: urlWmsIgmeLitologias1M,
    capas: ['0'],
    capasConsulta: [0],
  ),
];

/// Capa por defecto cuando se invoca la consulta sin que haya ninguna capa
/// geológica activa en el mapa (p. ej. desde el formulario de Nuevo
/// hallazgo). GEODE 50 es el continuo nacional con mejor cobertura y
/// granularidad estratigráfica.
CapaGeologicaWms get capaGeologicaConsultaDefecto =>
    capasGeologicasWms.firstWhere((c) => c.nombre == 'GEODE 50');

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

/// Clave de cache para una respuesta IGME. Antes redondeaba a 3 decimales
/// (≈111 m) y no incluía la capa consultada: dos puntos en estratos
/// vecinos a menos de 111 m daban la misma respuesta, y cambiar de capa
/// (GEODE→MAGNA→Edades) devolvía la respuesta cacheada de la capa
/// anterior. Ahora la clave atrapa URL+índice y baja la granularidad a
/// 4 decimales (≈11 m).
String _claveGeologia(double latitud, double longitud, CapaGeologicaWms capa) =>
    '${capa.urlBase}#${capa.capasConsulta.join('-')}@'
    '${latitud.toStringAsFixed(4)},${longitud.toStringAsFixed(4)}';

/// Sanea la clave para usarla como nombre de archivo (la URL contiene `://`,
/// `/`, `?` que rompen el path).
String _nombreArchivoCache(String clave) =>
    clave.replaceAll(RegExp(r'[^a-zA-Z0-9._@,#-]'), '_');

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
    final fichero = File(path_lib.join(dir.path, 'geologia_cache', '${_nombreArchivoCache(clave)}.json'));
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
    final fichero = File(path_lib.join(subdir.path, '${_nombreArchivoCache(clave)}.json'));
    await fichero.writeAsString(jsonEncode({
      'e': ctx.edad,
      'f': ctx.formacion,
      'l': ctx.litologia,
      'z': ctx.zona,
      'c': ctx.crudo,
    }));
  } catch (_) {}
}

/// Consulta el contexto geológico del IGME para [latitud]/[longitud] usando
/// la [capa] que el usuario tiene activa en el mapa. Si no se pasa capa, va
/// contra GEODE 50.
///
/// Estrategia con fallback: probamos primero la capa activa (lo que el
/// usuario tiene pintado y espera que cuadre con el punto). Si esa capa no
/// devuelve nada — porque MAGNA tiene huecos de cobertura, o los servicios
/// 1M solo cubren parcialmente, o el intérprete no entiende sus campos —
/// caemos a GEODE 50, que es el continuo nacional y siempre devuelve
/// alguna unidad estratigráfica.
Future<ContextoGeologico?> consultarContextoGeologico(
  double latitud,
  double longitud, {
  CapaGeologicaWms? capa,
}) async {
  final capaEfectiva = capa ?? capaGeologicaConsultaDefecto;
  final principal = await _consultarConCache(latitud, longitud, capaEfectiva);
  if (principal != null) return principal;
  // Fallback: si la capa activa no era GEODE, repreguntar contra GEODE.
  if (capaEfectiva.urlBase == urlWmsIgmeGeode) return null;
  return _consultarConCache(latitud, longitud, capaGeologicaConsultaDefecto);
}

Future<ContextoGeologico?> _consultarConCache(
  double latitud,
  double longitud,
  CapaGeologicaWms capa,
) async {
  final clave = _claveGeologia(latitud, longitud, capa);
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
    final resultado = await _intentarConsultarWms(latitud, longitud, capa);
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

class _ResultadoConsultaWms {
  final ContextoGeologico? contexto;
  final bool sinDatos;
  final bool fallo;
  _ResultadoConsultaWms.conContexto(this.contexto) : sinDatos = false, fallo = false;
  _ResultadoConsultaWms.sinDatosLegitimo() : contexto = null, sinDatos = true, fallo = false;
  _ResultadoConsultaWms.error() : contexto = null, sinDatos = false, fallo = true;
  bool get exitoEfectivo => !fallo;
}

Future<_ResultadoConsultaWms> _intentarConsultarWms(
  double latitud,
  double longitud,
  CapaGeologicaWms capa,
) async {
  final delta = 0.0005;
  final bbox = '${longitud - delta},${latitud - delta},${longitud + delta},${latitud + delta}';
  final indicesCapasComoCsv = capa.capasConsulta.join(',');
  // feature_count debe poder devolver al menos 1 feature por capa
  // consultada (más algún solapamiento). 5 era suficiente para una sola
  // capa; con multi-capa lo subimos a 5 por capa para no quedarnos cortos.
  final featureCountEfectivo = (capa.capasConsulta.length * 5).toString();
  final params = <String, String>{
    'service': 'WMS',
    'version': '1.1.1',
    'request': 'GetFeatureInfo',
    'layers': indicesCapasComoCsv,
    'query_layers': indicesCapasComoCsv,
    'styles': '',
    'bbox': bbox,
    'srs': 'EPSG:4326',
    'width': '101',
    'height': '101',
    'x': '50',
    'y': '50',
    'format': 'image/png',
    'info_format': 'application/geo+json',
    'feature_count': featureCountEfectivo,
  };
  final uri = Uri.parse(capa.urlBase).replace(queryParameters: params);
  try {
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 12));
    if (respuesta.statusCode >= 500 || respuesta.statusCode == 408 || respuesta.statusCode == 429) {
      return _ResultadoConsultaWms.error();
    }
    if (respuesta.statusCode != 200) return _ResultadoConsultaWms.sinDatosLegitimo();
    final cuerpo = utf8.decode(respuesta.bodyBytes);
    if (!cuerpo.trim().startsWith('{')) return _ResultadoConsultaWms.error();
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    final features = (json['features'] as List?) ?? const [];
    if (features.isEmpty) return _ResultadoConsultaWms.sinDatosLegitimo();
    // Multi-capa: la respuesta puede traer una feature por capa que
    // coincide en el pixel consultado. Ordenamos por especificidad
    // (índice de capa más alto = más específico; en GEODE 50 la capa 3
    // = Cuaternario - Recintos tiene mayor detalle que la 1 = Recintos
    // generales) y fusionamos sus propiedades dando prioridad a la más
    // específica.
    final listaPropiedades = features
        .where((f) => f is Map && f['properties'] is Map)
        .map((f) {
          final mapa = f as Map;
          final props = (mapa['properties'] as Map).cast<String, dynamic>();
          // Esri devuelve `layerName` (string) en cada feature. Si no
          // viene, intentamos extraer el índice de un eventual `layerId`;
          // si no, asumimos índice 0.
          final nombreCapa = (mapa['layerName'] as String?)?.trim();
          final indiceCapaFeature = _emparejarIndiceCapa(
            nombreCapa: nombreCapa,
            capasDeclaradas: capa.capasConsulta,
            indiceLayerId: mapa['layerId'] is num ? (mapa['layerId'] as num).toInt() : null,
          );
          return _FeaturePorCapa(indice: indiceCapaFeature, propiedades: props, layerName: nombreCapa);
        })
        .toList();
    if (listaPropiedades.isEmpty) return _ResultadoConsultaWms.sinDatosLegitimo();
    // Orden ascendente: la última en aplicar (= más específica) sobrescribe.
    listaPropiedades.sort((a, b) => a.indice.compareTo(b.indice));
    final propiedadesFusionadas = <String, dynamic>{};
    for (final feature in listaPropiedades) {
      propiedadesFusionadas.addAll(feature.propiedades);
    }
    return _ResultadoConsultaWms.conContexto(interpretarPropiedadesGeode(propiedadesFusionadas));
  } catch (_) {
    return _ResultadoConsultaWms.error();
  }
}

/// Empareja una feature con el índice numérico de su capa para poder
/// ordenarlas por especificidad. Esri WMS suele devolver `layerName` (p. ej.
/// "Recintos geología" o "Cuaternario - Recintos"); si la respuesta declara
/// `layerId` lo usamos directo. Si no podemos identificar la capa, asumimos
/// el primer índice declarado (= menos específico) para no perder la
/// feature pero tampoco sobrescribir lo bueno.
int _emparejarIndiceCapa({
  required String? nombreCapa,
  required List<int> capasDeclaradas,
  int? indiceLayerId,
}) {
  if (indiceLayerId != null && capasDeclaradas.contains(indiceLayerId)) {
    return indiceLayerId;
  }
  if (nombreCapa != null) {
    final nombreNormalizado = nombreCapa.toLowerCase();
    // Heurística: si el nombre incluye "cuaternario" lo tratamos como capa 3
    // de GEODE 50 (Cuaternario - Recintos). Aporta detalle de depósito.
    if (nombreNormalizado.contains('cuaternario')) return 3;
    if (nombreNormalizado.contains('recintos')) return 1;
  }
  return capasDeclaradas.first;
}

class _FeaturePorCapa {
  final int indice;
  final Map<String, dynamic> propiedades;
  final String? layerName;
  _FeaturePorCapa({required this.indice, required this.propiedades, this.layerName});
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
  // Edades 1M no expone Edad Inferior/Superior, sino "Sistema" (= Período:
  // Cuaternario, Cretácico…) y "Eon-Era" como menos específico. Sin esto
  // Edades 1M devolvía polígono pero el intérprete sacaba edad=null y el
  // panel del asistente decía "Sin datos".
  final sistema1M = lookup(['Sistema', 'SISTEMA']);
  final eonEra1M = lookup(['Eon-Era', 'EON-ERA', 'Eon Era']);
  // GEODE 50 expone "Descripción Unidad Geológica"; MAGNA 50 usa
  // "descripción litológica" (minúsculas + tilde); los servicios 1M usan
  // claves variadas (DESCRIPCION / Descripcion). Probamos todas.
  final descripcion = lookup([
    'Descripción Unidad Geológica', 'DESCRIPCION', 'Descripcion',
    'descripción litológica', 'Descripción litológica',
    'descripcion litologica',
  ]);
  final formacion = lookup(['Formacion', 'FORMACION', 'Unidad', 'UNIDAD']);
  final litologia = lookup(['Litologia', 'LITOLOGIA', 'LITOLOGÍA']);

  String? edad;
  if (edadInferior != null && edadSuperior != null && edadInferior != edadSuperior) {
    edad = '$edadInferior – $edadSuperior';
  } else {
    edad = edadSuperior ?? edadInferior ?? sistema1M ?? eonEra1M;
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
