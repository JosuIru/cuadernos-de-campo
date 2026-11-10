import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as ruta;
import 'package:path_provider/path_provider.dart';

import 'cache_con_caducidad.dart';
import 'cliente_api_abierta.dart';
import 'fotos_inaturalist.dart';
import 'presencia_gbif.dart';
import 'ubicacion_aproximada.dart';

/// Datos de iNaturalist y GBIF para la guía, con caché en disco.
///
/// - Fotos de iNaturalist: 30 días.
/// - Recuentos y meses de GBIF: 7 días.
/// - Claves de GBIF (`species/match`): 180 días.
///
/// Sin red (o si la API falla) se devuelve lo cacheado aunque esté
/// caducado; si no hay nada, null. Una petición a la misma clave mientras
/// otra está en vuelo reutiliza la misma.
class ServicioFuentesAbiertas {
  ServicioFuentesAbiertas({
    required ClienteApiAbierta clienteInaturalist,
    required ClienteApiAbierta clienteGbif,
    required CacheConCaducidad cache,
    DateTime Function()? reloj,
  })  : _clienteInaturalist = clienteInaturalist,
        _clienteGbif = clienteGbif,
        _cache = cache,
        _reloj = reloj ?? DateTime.now;

  static const Duration vigenciaFotos = Duration(days: 30);
  static const Duration vigenciaRecuentos = Duration(days: 7);
  static const Duration vigenciaClaves = Duration(days: 180);

  static ServicioFuentesAbiertas? _instancia;

  /// Instancia de la app: un cliente por API (cada uno con su cola) y la
  /// caché en `documentos/fuentes_abiertas_cache.json`.
  static ServicioFuentesAbiertas get instancia => _instancia ??= ServicioFuentesAbiertas(
        clienteInaturalist: ClienteApiAbierta(cliente: http.Client()),
        clienteGbif: ClienteApiAbierta(cliente: http.Client()),
        cache: CacheConCaducidad(AlmacenCacheFichero(() async {
          final documentos = await getApplicationDocumentsDirectory();
          return File(ruta.join(documentos.path, 'fuentes_abiertas_cache.json'));
        })),
      );

  final ClienteApiAbierta _clienteInaturalist;
  final ClienteApiAbierta _clienteGbif;
  final CacheConCaducidad _cache;
  final DateTime Function() _reloj;
  final Map<String, Future<Object?>> _enVuelo = {};

  /// Fotos abiertas de la especie (hasta 8).
  Future<FotosInaturalist?> fotosDe(String nombreCientifico) => _conCache<FotosInaturalist>(
        clave: 'inat:fotos:${nombreCientifico.trim().toLowerCase()}',
        vigencia: vigenciaFotos,
        pedir: () async => parsearObservacionesInaturalist(
          await _clienteInaturalist.obtenerJson(uriObservacionesConFotosAbiertas(nombreCientifico)),
          nombreCientifico: nombreCientifico,
        ),
        aJson: (fotos) => fotos.toJson(),
        desdeJson: FotosInaturalist.fromJson,
      );

  /// Solo lo que haya en caché, sin red (miniaturas de la lista).
  Future<FotosInaturalist?> fotosEnCache(String nombreCientifico) async {
    final entrada = await _cache.leer('inat:fotos:${nombreCientifico.trim().toLowerCase()}');
    return entrada == null ? null : FotosInaturalist.fromJson(entrada.datos);
  }

  /// Clave de especie de GBIF: [claveConocida] (la de la guía) o
  /// `species/match`.
  Future<int?> claveGbifDe(String nombreCientifico, {int? claveConocida}) async {
    if (claveConocida != null) return claveConocida;
    return _conCache<int>(
      clave: 'gbif:clave:${nombreCientifico.trim().toLowerCase()}',
      vigencia: vigenciaClaves,
      pedir: () async {
        final clave = claveEspecieDeEmparejamiento(
          await _clienteGbif.obtenerJson(uriEmparejarEspecieGbif(nombreCientifico)),
        );
        // Sin coincidencia: se cachea un 0 para no volver a preguntar.
        return clave ?? 0;
      },
      aJson: (clave) => clave,
      desdeJson: (crudo) => crudo is int ? crudo : 0,
    ).then((clave) => clave == null || clave == 0 ? null : clave);
  }

  /// Registros de la especie en la zona (o en España y Portugal si
  /// [ubicacion] es null).
  ///
  /// Si [sensible] (protegida en la guía) se consulta directamente a escala
  /// amplia. Si GBIF devuelve coordenadas generalizadas a escala normal, se
  /// vuelve a consultar a escala amplia y se devuelve esa.
  Future<PresenciaGbif?> presenciaDe(
    int claveEspecie, {
    UbicacionAproximada? ubicacion,
    bool sensible = false,
  }) async {
    final zona = sensible ? ubicacion?.aEscalaAmplia() : ubicacion;
    final presencia = await _presenciaEnZona(claveEspecie, zona);
    if (presencia != null && zona != null && !zona.escalaAmplia && presencia.coordenadasGeneralizadas) {
      return await _presenciaEnZona(claveEspecie, zona.aEscalaAmplia()) ?? _sinDetalle(presencia, zona.aEscalaAmplia());
    }
    return presencia;
  }

  /// Si la consulta amplia falla tras detectar coordenadas generalizadas, no
  /// se enseña el recuento fino: queda solo la marca de especie sensible.
  PresenciaGbif _sinDetalle(PresenciaGbif fina, UbicacionAproximada amplia) => PresenciaGbif(
        claveEspecie: fina.claveEspecie,
        total: 0,
        porMes: List<int>.filled(12, 0),
        consultadoEn: fina.consultadoEn,
        ubicacion: amplia,
        coordenadasGeneralizadas: true,
      );

  Future<PresenciaGbif?> _presenciaEnZona(int claveEspecie, UbicacionAproximada? zona) {
    final textoZona = zona == null ? 'iberia' : '${zona.parametroDistanciaGbif}${zona.escalaAmplia ? ':amplia' : ''}';
    return _conCache<PresenciaGbif>(
      clave: 'gbif:presencia:$claveEspecie:$textoZona',
      vigencia: vigenciaRecuentos,
      pedir: () async => parsearPresenciaGbif(
        await _clienteGbif.obtenerJson(uriPresenciaGbif(claveEspecie, zona)),
        claveEspecie: claveEspecie,
        ubicacion: zona,
        consultadoEn: _reloj(),
      ),
      aJson: (presencia) => presencia.toJson(),
      desdeJson: (crudo) => PresenciaGbif.fromJson(crudo),
    );
  }

  /// Claves de especie por petición en [especiesCerca] (200 ya pasan de
  /// 3,5 KB de URL; con 246 GBIF devuelve 400).
  static const int clavesPorPeticion = 100;

  /// Recuento por especie de las [claves] en la zona.
  Future<EspeciesCercaGbif?> especiesCerca(UbicacionAproximada ubicacion, Iterable<int> claves) {
    final listaClaves = claves.toSet().toList()..sort();
    return _conCache<EspeciesCercaGbif>(
      clave: 'gbif:cerca:${ubicacion.parametroDistanciaGbif}:${listaClaves.length}:${huellaDeClaves(listaClaves)}',
      vigencia: vigenciaRecuentos,
      pedir: () async {
        // GBIF rechaza URL de más de ~4 KB: lotes de [clavesPorPeticion]
        // claves, en serie como todo lo demás.
        final recuentos = <int, int>{};
        for (var inicio = 0; inicio < listaClaves.length; inicio += clavesPorPeticion) {
          final lote = listaClaves.sublist(inicio, (inicio + clavesPorPeticion).clamp(0, listaClaves.length));
          recuentos.addAll(parsearEspeciesCercaGbif(
            await _clienteGbif.obtenerJson(uriEspeciesCercaGbif(ubicacion, lote)),
          ));
        }
        return EspeciesCercaGbif(recuentos: recuentos, consultadoEn: _reloj());
      },
      aJson: (especies) => especies.toJson(),
      desdeJson: EspeciesCercaGbif.fromJson,
    );
  }

  Future<T?> _conCache<T extends Object>({
    required String clave,
    required Duration vigencia,
    required Future<T> Function() pedir,
    required Object? Function(T) aJson,
    required T? Function(Object?) desdeJson,
  }) {
    final enVuelo = _enVuelo[clave];
    if (enVuelo != null) return enVuelo.then((valor) => valor as T?);
    final futuro = () async {
      final entrada = await _cache.leer(clave);
      final cacheado = entrada == null ? null : desdeJson(entrada.datos);
      if (entrada != null && cacheado != null && !entrada.caducadaPara(vigencia, _reloj())) {
        return cacheado;
      }
      try {
        final nuevo = await pedir();
        await _cache.guardar(clave, aJson(nuevo));
        return nuevo;
      } catch (_) {
        return cacheado;
      }
    }();
    _enVuelo[clave] = futuro;
    return futuro.whenComplete(() => _enVuelo.remove(clave));
  }
}

/// Huella estable (FNV-1a de 32 bits) de una lista de claves, para la clave
/// de caché. `Object.hashAll` no sirve: cambia de una ejecución a otra.
String huellaDeClaves(List<int> claves) {
  var huella = 0x811c9dc5;
  for (final unidad in claves.join(',').codeUnits) {
    huella ^= unidad;
    huella = (huella * 0x01000193) & 0xffffffff;
  }
  return huella.toRadixString(16);
}

/// Recuento por especie cerca de la persona.
class EspeciesCercaGbif {
  const EspeciesCercaGbif({required this.recuentos, required this.consultadoEn});

  final Map<int, int> recuentos;
  final DateTime consultadoEn;

  Map<String, Object?> toJson() => {
        'fecha': consultadoEn.toIso8601String(),
        'recuentos': {for (final entrada in recuentos.entries) '${entrada.key}': entrada.value},
      };

  static EspeciesCercaGbif? fromJson(Object? crudo) {
    if (crudo is! Map) return null;
    final fecha = DateTime.tryParse((crudo['fecha'] as String?) ?? '');
    final mapa = crudo['recuentos'];
    if (fecha == null || mapa is! Map) return null;
    final recuentos = <int, int>{};
    mapa.forEach((clave, valor) {
      final claveEntera = int.tryParse('$clave');
      if (claveEntera != null && valor is num) recuentos[claveEntera] = valor.toInt();
    });
    return EspeciesCercaGbif(recuentos: recuentos, consultadoEn: fecha);
  }
}
