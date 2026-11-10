import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/cache_con_caducidad.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/cliente_api_abierta.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/metadatos_commons.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/servicio_metadatos_commons.dart';

Map<String, dynamic> _pagina(String titulo, {String? artista, String? licencia, String? url, String? noLibre}) => {
      'title': titulo,
      'imageinfo': [
        {
          'descriptionurl': 'https://commons.wikimedia.org/wiki/${titulo.replaceAll(' ', '_')}',
          'extmetadata': {
            if (artista != null) 'Artist': {'value': artista},
            if (licencia != null) 'LicenseShortName': {'value': licencia},
            if (url != null) 'LicenseUrl': {'value': url},
            if (noLibre != null) 'NonFree': {'value': noLibre},
          },
        }
      ],
    };

void main() {
  group('fichero de Commons desde la URL', () {
    test('miniatura y original de Commons', () {
      expect(
        archivoCommonsDesdeUrl(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Erithacus_rubecula_with_cocked_head.jpg/600px-Erithacus_rubecula_with_cocked_head.jpg'),
        'Erithacus rubecula with cocked head.jpg',
      );
      expect(
        archivoCommonsDesdeUrl('//upload.wikimedia.org/wikipedia/commons/a/ab/Pica_pica_%28Mallorca%29.jpg'),
        'Pica pica (Mallorca).jpg',
      );
      // Las galerías de Wikipedia ya sirven las miniaturas desde thumb.wikimedia.org.
      expect(
        archivoCommonsDesdeUrl(
            '//thumb.wikimedia.org/wikipedia/commons/thumb/c/c2/Vulpes_vulpes_2.jpg/500px-Vulpes_vulpes_2.jpg?utm_source=es.wikipedia.org&utm_campaign=parser'),
        'Vulpes vulpes 2.jpg',
      );
    });

    test('las subidas locales de una Wikipedia no cuentan', () {
      expect(archivoCommonsDesdeUrl('https://upload.wikimedia.org/wikipedia/en/thumb/a/ab/Logo.jpg/600px-Logo.jpg'),
          isNull);
      expect(archivoCommonsDesdeUrl('https://static.inaturalist.org/photos/1/medium.jpg'), isNull);
    });

    test('la petición pide extmetadata de todos los ficheros', () {
      final uri = uriMetadatosCommons(['A b.jpg', 'C.png']);
      expect(uri.host, 'commons.wikimedia.org');
      expect(uri.queryParameters['titles'], 'File:A b.jpg|File:C.png');
      expect(uri.queryParameters['iiprop'], contains('extmetadata'));
      expect(uri.queryParameters['iiextmetadatafilter'], contains('LicenseShortName'));
    });
  });

  group('licencias libres', () {
    test('acepta CC0, dominio público, CC BY y CC BY-SA', () {
      expect(licenciaLibreCommons('CC0'), LicenciaCommons.cc0);
      expect(licenciaLibreCommons('Public domain'), LicenciaCommons.dominioPublico);
      expect(licenciaLibreCommons('PD-old-100'), LicenciaCommons.dominioPublico);
      expect(licenciaLibreCommons('CC BY 2.0'), LicenciaCommons.ccBy);
      expect(licenciaLibreCommons('CC BY-SA 4.0'), LicenciaCommons.ccBySa);
      expect(licenciaLibreCommons('CC BY-SA 3.0 de'), LicenciaCommons.ccBySa);
      expect(licenciaLibreCommons('CC-BY-SA-2.5'), LicenciaCommons.ccBySa);
      expect(licenciaLibreCommons('CC BY-SA 3.0 IGO'), LicenciaCommons.ccBySa);
    });

    test('rechaza NC, ND, GFDL y lo desconocido', () {
      for (final licencia in [
        'CC BY-NC 2.0',
        'CC BY-NC-SA 4.0',
        'CC BY-ND 3.0',
        'GFDL',
        'Free Art License',
        'Attribution',
        'Fair use',
        '',
        null,
      ]) {
        expect(licenciaLibreCommons(licencia), isNull, reason: '$licencia');
      }
    });

    test('texto plano del autor con enlaces y entidades', () {
      expect(textoPlanoDeHtml('<a href="//commons.wikimedia.org/wiki/User:X">Jos&eacute;</a>'), 'Jos&eacute;');
      expect(textoPlanoDeHtml('<a href="x">Ana &amp; Luis</a><br/> (Flickr)'), 'Ana & Luis (Flickr)');
      expect(textoPlanoDeHtml('&#77;aría'), 'María');
    });
  });

  group('parseo de la respuesta', () {
    test('autor y licencia; descarta no libres y CC BY sin autor', () {
      final metadatos = parsearMetadatosCommons({
        'query': {
          'pages': [
            _pagina('File:Erithacus rubecula.jpg',
                artista: '<a href="x">Francis C. Franklin</a>',
                licencia: 'CC BY-SA 3.0',
                url: 'https://creativecommons.org/licenses/by-sa/3.0'),
            _pagina('File:Con nc.jpg', artista: 'Alguien', licencia: 'CC BY-NC 2.0'),
            _pagina('File:Sin autor.jpg', licencia: 'CC BY 4.0'),
            _pagina('File:Antigua.jpg', licencia: 'Public domain'),
            _pagina('File:No libre.jpg', artista: 'X', licencia: 'CC BY 4.0', noLibre: 'true'),
            {'title': 'File:Falta.jpg', 'missing': true},
          ],
        },
      });
      final petirrojo = metadatos['Erithacus rubecula.jpg']!;
      expect(petirrojo.autor, 'Francis C. Franklin');
      expect(petirrojo.licenciaCorta, 'CC BY-SA 3.0');
      expect(petirrojo.textoAtribucion, '© Francis C. Franklin · CC BY-SA 3.0');
      expect(petirrojo.urlLicencia, 'https://creativecommons.org/licenses/by-sa/3.0');
      expect(petirrojo.urlDescripcion, contains('commons.wikimedia.org/wiki/File:Erithacus_rubecula.jpg'));
      expect(metadatos.containsKey('Con nc.jpg'), isTrue);
      expect(metadatos['Con nc.jpg'], isNull);
      expect(metadatos['Sin autor.jpg'], isNull);
      expect(metadatos['Antigua.jpg']!.textoAtribucion, 'Public domain');
      expect(metadatos['No libre.jpg'], isNull);
      expect(metadatos['Falta.jpg'], isNull);
    });

    test('ida y vuelta por JSON (caché)', () {
      const metadatos = MetadatosFotoCommons(
        archivo: 'A.jpg',
        autor: 'Ana',
        licencia: LicenciaCommons.ccBy,
        licenciaCorta: 'CC BY 4.0',
        urlLicencia: 'https://creativecommons.org/licenses/by/4.0',
      );
      final vuelta = MetadatosFotoCommons.desdeJson(jsonDecode(jsonEncode(metadatos.aJson())))!;
      expect(vuelta.textoAtribucion, metadatos.textoAtribucion);
      expect(vuelta.licencia, LicenciaCommons.ccBy);
    });
  });

  group('servicio con caché', () {
    test('una petición para toda la galería, y la segunda vez de la caché', () async {
      var peticiones = 0;
      final cliente = ClienteApiAbierta(
        cliente: MockClient((peticion) async {
          peticiones++;
          expect(peticion.url.queryParameters['titles'], 'File:A.jpg|File:B.jpg');
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'query': {
                  'pages': [
                    _pagina('File:A.jpg', artista: 'Ana', licencia: 'CC BY 4.0'),
                    _pagina('File:B.jpg', artista: 'Bea', licencia: 'CC BY-NC 4.0'),
                  ],
                },
              })),
              200);
        }),
        esperar: (_) async {},
      );
      final servicio = ServicioMetadatosCommons(cliente: cliente, cache: CacheConCaducidad(AlmacenCacheMemoria()));
      const urls = [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/A.jpg/600px-A.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/B.jpg/600px-B.jpg',
        'https://upload.wikimedia.org/wikipedia/es/thumb/c/cc/C.jpg/600px-C.jpg',
      ];
      final primera = await servicio.metadatosDe(urls);
      expect(primera[0]?.autor, 'Ana');
      expect(primera[1], isNull);
      expect(primera[2], isNull);
      final segunda = await servicio.metadatosDe(urls);
      expect(segunda[0]?.autor, 'Ana');
      expect(segunda[1], isNull);
      expect(peticiones, 1);
    });

    test('sin red y sin caché, ninguna foto se da por libre', () async {
      final cliente = ClienteApiAbierta(
        cliente: MockClient((_) async => throw const ErrorApiAbierta('sin red')),
        esperar: (_) async {},
      );
      final servicio = ServicioMetadatosCommons(cliente: cliente, cache: CacheConCaducidad(AlmacenCacheMemoria()));
      final resultado = await servicio
          .metadatosDe(['https://upload.wikimedia.org/wikipedia/commons/a/aa/A.jpg']);
      expect(resultado, [isNull]);
    });
  });
}
