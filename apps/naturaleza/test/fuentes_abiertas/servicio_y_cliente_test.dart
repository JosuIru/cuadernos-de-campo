import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/cache_con_caducidad.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/cliente_api_abierta.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/servicio_fuentes_abiertas.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/ubicacion_aproximada.dart';
import 'package:naturaleza_flutter/utiles/enlaces_app.dart';

/// Reloj falso que solo avanza cuando el cliente «espera».
class _RelojFalso {
  DateTime ahora = DateTime(2026, 11, 10, 12);
  final List<Duration> esperas = [];

  Future<void> esperar(Duration duracion) async {
    esperas.add(duracion);
    ahora = ahora.add(duracion);
  }
}

http.Response _json(Object cuerpo, {int codigo = 200, Map<String, String> cabeceras = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo, headers: {'content-type': 'application/json', ...cabeceras});

void main() {
  group('cliente de API abierta', () {
    test('en serie, con User-Agent y al menos 1,1 s entre peticiones', () async {
      final reloj = _RelojFalso();
      final instantes = <DateTime>[];
      final agentes = <String?>[];
      final cliente = ClienteApiAbierta(
        cliente: MockClient((peticion) async {
          instantes.add(reloj.ahora);
          agentes.add(peticion.headers['User-Agent']);
          return _json({'ok': true});
        }),
        reloj: () => reloj.ahora,
        esperar: reloj.esperar,
      );
      await Future.wait([
        for (var indice = 0; indice < 3; indice++) cliente.obtenerJson(Uri.parse('https://api.gbif.org/v1/x?$indice')),
      ]);
      expect(instantes.length, 3);
      for (var indice = 1; indice < instantes.length; indice++) {
        expect(instantes[indice].difference(instantes[indice - 1]) >= const Duration(milliseconds: 1100), isTrue);
      }
      expect(agentes.every((agente) => agente == agenteUsuarioNaturaleza), isTrue);
      expect(agenteUsuarioNaturaleza.contains('@'), isFalse);
    });

    test('ante un 429 espera Retry-After y reintenta', () async {
      final reloj = _RelojFalso();
      var llamadas = 0;
      final cliente = ClienteApiAbierta(
        cliente: MockClient((_) async {
          llamadas++;
          return llamadas == 1 ? _json({}, codigo: 429, cabeceras: {'retry-after': '7'}) : _json({'bien': 1});
        }),
        reloj: () => reloj.ahora,
        esperar: reloj.esperar,
      );
      expect(await cliente.obtenerJson(Uri.parse('https://api.inaturalist.org/v1/x')), {'bien': 1});
      expect(llamadas, 2);
      expect(reloj.esperas, contains(const Duration(seconds: 7)));
    });

    test('tras varios 429 se rinde con un error; la cola sigue viva', () async {
      final reloj = _RelojFalso();
      var llamadas = 0;
      final cliente = ClienteApiAbierta(
        cliente: MockClient((peticion) async {
          llamadas++;
          return peticion.url.path.endsWith('mal') ? _json({}, codigo: 429) : _json({'bien': 1});
        }),
        reloj: () => reloj.ahora,
        esperar: reloj.esperar,
        reintentosPor429: 2,
      );
      await expectLater(
        cliente.obtenerJson(Uri.parse('https://api.gbif.org/v1/mal')),
        throwsA(isA<ErrorApiAbierta>().having((error) => error.codigo, 'codigo', 429)),
      );
      expect(llamadas, 3);
      expect(reloj.esperas.where((espera) => espera == const Duration(seconds: 30)).length, greaterThanOrEqualTo(2));
      expect(await cliente.obtenerJson(Uri.parse('https://api.gbif.org/v1/bien')), {'bien': 1});
    });

    test('Retry-After acotado', () {
      final cliente = ClienteApiAbierta(cliente: MockClient((_) async => _json({})));
      expect(cliente.esperaTras429('3600'), const Duration(minutes: 2));
      expect(cliente.esperaTras429('0'), const Duration(seconds: 1));
      expect(cliente.esperaTras429('Wed, 21 Oct 2026 07:28:00 GMT'), const Duration(seconds: 30));
      expect(cliente.esperaTras429(null), const Duration(seconds: 30));
    });
  });

  group('caché con caducidad', () {
    test('guarda, lee, caduca y se tiran las muy viejas al cargar', () async {
      final reloj = _RelojFalso();
      final almacen = AlmacenCacheMemoria();
      final cache = CacheConCaducidad(almacen, reloj: () => reloj.ahora);
      await cache.guardar('a', {'x': 1});
      var entrada = (await cache.leer('a'))!;
      expect(entrada.datos, {'x': 1});
      expect(entrada.caducadaPara(const Duration(days: 7), reloj.ahora), isFalse);
      reloj.ahora = reloj.ahora.add(const Duration(days: 8));
      entrada = (await cache.leer('a'))!;
      expect(entrada.caducadaPara(const Duration(days: 7), reloj.ahora), isTrue);
      expect(entrada.caducadaPara(const Duration(days: 30), reloj.ahora), isFalse);

      reloj.ahora = reloj.ahora.add(const Duration(days: 200));
      final recargada = CacheConCaducidad(almacen, reloj: () => reloj.ahora);
      expect(await recargada.leer('a'), isNull);
    });
  });

  group('servicio de fuentes abiertas', () {
    late _RelojFalso reloj;
    late List<Uri> pedidas;
    late bool sinRed;

    ServicioFuentesAbiertas crearServicio(AlmacenCache almacen, Future<http.Response> Function(http.Request) responder) {
      final clienteHttp = MockClient((peticion) async {
        if (sinRed) throw http.ClientException('sin red');
        pedidas.add(peticion.url);
        return responder(peticion);
      });
      ClienteApiAbierta nuevoCliente() =>
          ClienteApiAbierta(cliente: clienteHttp, reloj: () => reloj.ahora, esperar: reloj.esperar);
      return ServicioFuentesAbiertas(
        clienteInaturalist: nuevoCliente(),
        clienteGbif: nuevoCliente(),
        cache: CacheConCaducidad(almacen, reloj: () => reloj.ahora),
        reloj: () => reloj.ahora,
      );
    }

    setUp(() {
      reloj = _RelojFalso();
      pedidas = [];
      sinRed = false;
    });

    final respuestaFotos = {
      'results': [
        {
          'id': 1,
          'uri': 'https://www.inaturalist.org/observations/1',
          'taxon': {'id': 13094, 'name': 'Erithacus rubecula'},
          'photos': [
            {
              'id': 11,
              'license_code': 'cc-by',
              'attribution_name': 'Ana',
              'url': 'https://inaturalist-open-data.s3.amazonaws.com/photos/11/square.jpg',
            },
          ],
        },
      ],
    };

    test('fotos: una petición, luego caché 30 días; sin red, lo cacheado', () async {
      final almacen = AlmacenCacheMemoria();
      final servicio = crearServicio(almacen, (_) async => _json(respuestaFotos));
      final primeras = await servicio.fotosDe('Erithacus rubecula');
      expect(primeras!.fotos.single.idFoto, 11);
      await servicio.fotosDe('Erithacus rubecula');
      expect(pedidas.length, 1);

      // Caducada y sin red: devuelve la caché vieja.
      reloj.ahora = reloj.ahora.add(const Duration(days: 31));
      sinRed = true;
      final otraSesion = crearServicio(almacen, (_) async => _json(respuestaFotos));
      expect((await otraSesion.fotosDe('Erithacus rubecula'))!.fotos.single.idFoto, 11);
      expect((await otraSesion.fotosEnCache('erithacus rubecula'))!.fotos.length, 1);
      // Sin caché y sin red: nada.
      expect(await otraSesion.fotosDe('Turdus merula'), isNull);
    });

    test('peticiones simultáneas a la misma clave se juntan', () async {
      final servicio = crearServicio(AlmacenCacheMemoria(), (_) async => _json(respuestaFotos));
      await Future.wait([servicio.fotosDe('Erithacus rubecula'), servicio.fotosDe('Erithacus rubecula')]);
      expect(pedidas.length, 1);
    });

    test('presencia: especie protegida va directa a escala amplia', () async {
      final servicio = crearServicio(AlmacenCacheMemoria(), (_) async => _json({'count': 3, 'results': [], 'facets': []}));
      final zona = UbicacionAproximada.desde(43.26, -2.93);
      final presencia = await servicio.presenciaDe(41976, ubicacion: zona, sensible: true);
      expect(presencia!.ubicacion!.escalaAmplia, isTrue);
      expect(pedidas.single.queryParameters['geoDistance'], '43.5,-3.0,75km');
    });

    test('presencia: si GBIF generaliza coordenadas, se repite a escala amplia', () async {
      final servicio = crearServicio(AlmacenCacheMemoria(), (peticion) async {
        final amplia = peticion.url.queryParameters['geoDistance']!.endsWith('75km');
        return _json({
          'count': amplia ? 40 : 2,
          'results': [
            if (!amplia) {'key': 1, 'dataGeneralizations': 'Coordinate uncertainty increased to 10000m'},
          ],
          'facets': [],
        });
      });
      final presencia = await servicio.presenciaDe(5, ubicacion: UbicacionAproximada.desde(43.26, -2.93));
      expect(pedidas.length, 2);
      expect(presencia!.total, 40);
      expect(presencia.ubicacion!.escalaAmplia, isTrue);
    });

    test('presencia: caché de 7 días y clave de GBIF cacheada', () async {
      final servicio = crearServicio(AlmacenCacheMemoria(), (peticion) async {
        if (peticion.url.path.endsWith('/species/match')) {
          return _json({'usageKey': 2492462, 'speciesKey': 2492462, 'matchType': 'EXACT'});
        }
        return _json({'count': 9, 'results': [], 'facets': []});
      });
      expect(await servicio.claveGbifDe('Erithacus rubecula'), 2492462);
      expect(await servicio.claveGbifDe('Erithacus rubecula'), 2492462);
      expect(await servicio.claveGbifDe('Lo que sea', claveConocida: 8), 8);
      expect(pedidas.length, 1);
      await servicio.presenciaDe(2492462);
      await servicio.presenciaDe(2492462);
      expect(pedidas.length, 2);
      reloj.ahora = reloj.ahora.add(const Duration(days: 8));
      await servicio.presenciaDe(2492462);
      expect(pedidas.length, 3);
    });

    test('especies cerca: pocas claves, una petición; muchas, por lotes', () async {
      final servicio = crearServicio(
        AlmacenCacheMemoria(),
        (_) async => _json({
          'count': 10,
          'results': [],
          'facets': [
            {
              'field': 'SPECIES_KEY',
              'counts': [
                {'name': '2', 'count': 6},
              ],
            },
          ],
        }),
      );
      final cerca = await servicio.especiesCerca(UbicacionAproximada.desde(43.26, -2.93), [1, 2, 3]);
      expect(cerca!.recuentos, {2: 6});
      expect(pedidas.single.queryParametersAll['taxonKey'], ['1', '2', '3']);
      expect(huellaDeClaves([1, 2, 3]), huellaDeClaves([1, 2, 3]));
      // Muchas claves: lotes de 100.
      pedidas.clear();
      await servicio.especiesCerca(UbicacionAproximada.desde(40.4, -3.7), List.generate(230, (indice) => indice + 1));
      expect(pedidas.length, 3);
      expect(pedidas.every((uri) => uri.queryParametersAll['taxonKey']!.length <= 100), isTrue);
      expect(huellaDeClaves([1, 2, 3]) == huellaDeClaves([1, 2, 4]), isFalse);
    });
  });
}
