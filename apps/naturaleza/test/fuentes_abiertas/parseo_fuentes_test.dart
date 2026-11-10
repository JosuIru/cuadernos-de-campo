import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/fotos_inaturalist.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/licencias_abiertas.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/presencia_gbif.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/ubicacion_aproximada.dart';

Map<String, dynamic> _foto(int id, String? licencia, {String dominio = 'inaturalist-open-data.s3.amazonaws.com', String? autor = 'Ana'}) => {
      'id': id,
      'license_code': licencia,
      'attribution': autor == null ? null : '(c) $autor, some rights reserved',
      'attribution_name': autor,
      'url': 'https://$dominio/photos/$id/square.jpg',
    };

Map<String, dynamic> _observacion(int id, String taxon, List<Map<String, dynamic>> fotos, {int idTaxon = 13094}) => {
      'id': id,
      'uri': 'https://www.inaturalist.org/observations/$id',
      'taxon': {'id': idTaxon, 'name': taxon},
      'user': {'login': 'usuaria$id', 'name': ''},
      'photos': fotos,
    };

void main() {
  group('fotos de iNaturalist', () {
    test('solo pasan CC0, CC BY y CC BY-SA del dominio abierto, una por observación', () {
      final respuesta = {
        'results': [
          _observacion(1, 'Erithacus rubecula', [_foto(10, 'cc-by-nc'), _foto(11, 'cc-by')]),
          _observacion(2, 'Erithacus rubecula', [_foto(20, null, dominio: 'static.inaturalist.org')]),
          _observacion(3, 'Erithacus rubecula', [_foto(30, 'cc-by-sa'), _foto(31, 'cc0')]),
          _observacion(4, 'Erithacus rubecula', [_foto(40, 'cc-by-nd')]),
          _observacion(5, 'Erithacus rubecula', [_foto(50, 'cc0', dominio: 'static.inaturalist.org')]),
          _observacion(6, 'Erithacus rubecula', [_foto(60, 'cc0', autor: null)]),
        ],
      };
      final fotos = parsearObservacionesInaturalist(respuesta, nombreCientifico: 'Erithacus rubecula');
      expect(fotos.fotos.map((foto) => foto.idFoto), [11, 30, 60]);
      expect(fotos.idTaxon, 13094);
      expect(fotos.fotos.first.licencia, LicenciaAbierta.ccBy);
      expect(fotos.fotos.first.textoAtribucion, '© Ana · CC BY');
      expect(fotos.fotos.first.urlObservacion, 'https://www.inaturalist.org/observations/1');
      expect(fotos.fotos.first.urlMedia, endsWith('/photos/11/medium.jpg'));
      expect(fotos.fotos.first.urlGrande, endsWith('/photos/11/large.jpg'));
      // Sin attribution_name ni attribution: el nombre de usuario.
      expect(fotos.fotos.last.autor, 'usuaria6');
      expect(fotos.fotos.last.textoAtribucion, 'usuaria6 · CC0');
    });

    test('prefiere la especie pedida y respeta el máximo', () {
      final respuesta = {
        'results': [
          _observacion(1, 'Erithacus rubecula superbus', [_foto(10, 'cc-by')], idTaxon: 99),
          _observacion(2, 'Turdus merula', [_foto(20, 'cc-by')], idTaxon: 12716),
          for (var indice = 3; indice < 15; indice++)
            _observacion(indice, 'Erithacus rubecula', [_foto(indice * 10, 'cc0')]),
        ],
      };
      final fotos = parsearObservacionesInaturalist(respuesta, nombreCientifico: 'erithacus rubecula', maximoFotos: 4);
      expect(fotos.fotos.length, 4);
      expect(fotos.fotos.map((foto) => foto.idFoto).contains(20), isFalse);
      expect(fotos.fotos.first.idFoto, 10);
      expect(fotos.idTaxon, 13094);
    });

    test('ida y vuelta por JSON (caché) sin perder la licencia', () {
      final original = parsearObservacionesInaturalist({
        'results': [
          _observacion(1, 'Erithacus rubecula', [_foto(11, 'cc-by-sa')])
        ],
      }, nombreCientifico: 'Erithacus rubecula');
      final copia = FotosInaturalist.fromJson(original.toJson());
      expect(copia.idTaxon, 13094);
      expect(copia.fotos.single.licencia, LicenciaAbierta.ccBySa);
      expect(copia.fotos.single.autor, 'Ana');
      // Una entrada de caché con licencia no aceptada se descarta.
      expect(FotoAbierta.fromJson({'id': 1, 'url': 'x', 'licencia': 'cc-by-nc'}), isNull);
    });

    test('URL de búsqueda con el filtro de licencias', () {
      final uri = uriObservacionesConFotosAbiertas('Lynx pardinus');
      expect(uri.queryParameters['photo_license'], 'cc0,cc-by,cc-by-sa');
      expect(uri.queryParameters['taxon_name'], 'Lynx pardinus');
      expect(uriPaginaInaturalist('Lynx pardinus', idTaxon: 41976).toString(), 'https://www.inaturalist.org/taxa/41976');
      expect(uriPaginaInaturalist('Lynx pardinus').queryParameters['q'], 'Lynx pardinus');
    });
  });

  group('GBIF', () {
    test('clave de especie de species/match', () {
      expect(claveEspecieDeEmparejamiento({'usageKey': 5, 'speciesKey': 2492462, 'matchType': 'EXACT'}), 2492462);
      expect(claveEspecieDeEmparejamiento({'usageKey': 7, 'rank': 'SPECIES', 'matchType': 'FUZZY'}), 7);
      expect(claveEspecieDeEmparejamiento({'usageKey': 7, 'rank': 'GENUS', 'matchType': 'HIGHERRANK'}), isNull);
      expect(claveEspecieDeEmparejamiento({'matchType': 'NONE'}), isNull);
    });

    test('faceta por meses y recuento', () {
      final presencia = parsearPresenciaGbif({
        'count': 120,
        'results': [],
        'facets': [
          {
            'field': 'MONTH',
            'counts': [
              {'name': '4', 'count': 50},
              {'name': '5', 'count': 40},
              {'name': '12', 'count': 30},
              {'name': '13', 'count': 99},
            ],
          },
        ],
      }, claveEspecie: 1, ubicacion: null, consultadoEn: DateTime(2026, 11, 10));
      expect(presencia.total, 120);
      expect(presencia.porMes, [0, 0, 0, 50, 40, 0, 0, 0, 0, 0, 0, 30]);
      expect(presencia.coordenadasGeneralizadas, isFalse);
      final copia = PresenciaGbif.fromJson(presencia.toJson())!;
      expect(copia.porMes, presencia.porMes);
      expect(copia.ubicacion, isNull);
    });

    test('detecta coordenadas generalizadas en la muestra', () {
      expect(
          hayCoordenadasGeneralizadas({
            'results': [
              {'key': 1},
              {'key': 2, 'dataGeneralizations': 'Coordinates generalised to 10 km'},
            ],
          }),
          isTrue);
      expect(
          hayCoordenadasGeneralizadas({
            'results': [
              {'key': 1, 'informationWithheld': ' '},
            ],
          }),
          isFalse);
    });

    test('URL de presencia: zona aproximada, licencias sin NC y faceta por mes', () {
      final zona = UbicacionAproximada.desde(43.2639, -2.9351);
      final uri = uriPresenciaGbif(2492462, zona);
      expect(uri.queryParameters['geoDistance'], '43.3,-2.9,20km');
      expect(uri.queryParametersAll['license'], ['CC0_1_0', 'CC_BY_4_0']);
      expect(uri.queryParameters['facet'], 'month');
      expect(uri.toString().contains('43.2639'), isFalse);
      final sinZona = uriPresenciaGbif(2492462, null);
      expect(sinZona.queryParametersAll['country'], ['ES', 'PT']);
      expect(sinZona.queryParameters.containsKey('geoDistance'), isFalse);
    });

    test('especies cerca: faceta por especie de las claves dadas', () {
      final uri = uriEspeciesCercaGbif(UbicacionAproximada.desde(43.26, -2.93), [3, 1, 2, 1]);
      expect(uri.queryParametersAll['taxonKey'], ['1', '2', '3']);
      expect(uri.queryParameters['facetLimit'], '3');
      expect(uri.queryParameters['limit'], '0');
      expect(
          parsearEspeciesCercaGbif({
            'facets': [
              {
                'field': 'SPECIES_KEY',
                'counts': [
                  {'name': '2492462', 'count': 17},
                  {'name': '5', 'count': 0},
                ],
              },
            ],
          }),
          {2492462: 17});
    });

    test('meses con más registros y tramos que cruzan el año', () {
      expect(mesesConMasRegistros([0, 0, 0, 50, 40, 10, 0, 0, 0, 0, 0, 30]), [4, 5, 12]);
      expect(mesesConMasRegistros(List.filled(12, 0)), isEmpty);
      expect(tramosDeMeses([12, 1, 2, 5]), [
        [5, 5],
        [12, 2],
      ]);
      expect(tramosDeMeses([4, 5, 6]), [
        [4, 6]
      ]);
      expect(tramosDeMeses(List.generate(12, (indice) => indice + 1)), [
        [1, 12]
      ]);
    });

    test('cita simple de GBIF y enlaces', () {
      expect(textoCitaGbif(DateTime(2026, 11, 10)), 'GBIF.org (10 November 2026) GBIF Occurrence Data');
      expect(uriBusquedaRegistrosGbif(7).toString(), 'https://www.gbif.org/occurrence/search?taxon_key=7');
      expect(uriPaginaEspecieGbif(7).toString(), 'https://www.gbif.org/species/7');
    });
  });
}
