import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as ruta;
import 'package:path_provider/path_provider.dart';

import 'cache_con_caducidad.dart';
import 'cliente_api_abierta.dart';
import 'metadatos_commons.dart';

/// Autor y licencia de las fotos de Commons de la galería de Wikipedia, con
/// caché en disco (30 días; sin red se usa lo cacheado aunque esté
/// caducado). Una foto sin metadatos conocidos se trata como no libre: la
/// galería no la enseña.
class ServicioMetadatosCommons {
  ServicioMetadatosCommons({required ClienteApiAbierta cliente, required CacheConCaducidad cache, DateTime Function()? reloj})
      : _cliente = cliente,
        _cache = cache,
        _reloj = reloj ?? DateTime.now;

  static const Duration vigencia = Duration(days: 30);

  static ServicioMetadatosCommons? _instancia;

  /// Instancia de la app: cola propia (la API de Wikimedia pide peticiones
  /// en serie y User-Agent identificativo) y caché en
  /// `documentos/commons_cache.json`.
  static ServicioMetadatosCommons get instancia => _instancia ??= ServicioMetadatosCommons(
        cliente: ClienteApiAbierta(cliente: http.Client()),
        cache: CacheConCaducidad(AlmacenCacheFichero(() async {
          final documentos = await getApplicationDocumentsDirectory();
          return File(ruta.join(documentos.path, 'commons_cache.json'));
        })),
      );

  final ClienteApiAbierta _cliente;
  final CacheConCaducidad _cache;
  final DateTime Function() _reloj;

  String _claveCache(String archivo) => 'commons:$archivo';

  /// Metadatos de cada URL de la galería, en el mismo orden; null si la
  /// foto no es de Commons, no tiene licencia libre clara o no se ha podido
  /// saber.
  Future<List<MetadatosFotoCommons?>> metadatosDe(List<String> urls) async {
    final archivos = [for (final url in urls) archivoCommonsDesdeUrl(url)];
    final conocidos = <String, MetadatosFotoCommons?>{};
    final porPedir = <String>[];
    final caducadosCacheados = <String, MetadatosFotoCommons?>{};
    for (final archivo in archivos.whereType<String>().toSet()) {
      final entrada = await _cache.leer(_claveCache(archivo));
      if (entrada == null) {
        porPedir.add(archivo);
        continue;
      }
      final metadatos = _desdeCache(entrada.datos);
      if (entrada.caducadaPara(vigencia, _reloj())) {
        caducadosCacheados[archivo] = metadatos;
        porPedir.add(archivo);
      } else {
        conocidos[archivo] = metadatos;
      }
    }
    for (var inicio = 0; inicio < porPedir.length; inicio += maximoArchivosPorPeticionCommons) {
      final lote = porPedir.sublist(
          inicio, (inicio + maximoArchivosPorPeticionCommons).clamp(0, porPedir.length));
      try {
        final respuesta = parsearMetadatosCommons(await _cliente.obtenerJson(uriMetadatosCommons(lote)));
        for (final archivo in lote) {
          // Si la API no menciona el fichero, cuenta como no libre.
          final metadatos = respuesta[archivo];
          conocidos[archivo] = metadatos;
          await _cache.guardar(_claveCache(archivo), metadatos?.aJson() ?? const {'no_libre': true});
        }
      } catch (_) {
        // Sin red: lo caducado vale; lo que no esté, no se enseña.
        for (final archivo in lote) {
          conocidos[archivo] = caducadosCacheados[archivo];
        }
      }
    }
    return [for (final archivo in archivos) archivo == null ? null : conocidos[archivo]];
  }

  MetadatosFotoCommons? _desdeCache(Object? datos) {
    if (datos is Map && datos['no_libre'] == true) return null;
    return MetadatosFotoCommons.desdeJson(datos);
  }
}
