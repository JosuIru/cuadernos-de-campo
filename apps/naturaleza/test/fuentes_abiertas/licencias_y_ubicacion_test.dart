import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/licencias_abiertas.dart';
import 'package:naturaleza_flutter/fuentes_abiertas/ubicacion_aproximada.dart';

void main() {
  group('licencias aceptadas', () {
    test('acepta CC0, CC BY y CC BY-SA con o sin versión', () {
      expect(licenciaAbiertaDesdeCodigo('cc0'), LicenciaAbierta.cc0);
      expect(licenciaAbiertaDesdeCodigo('cc-by'), LicenciaAbierta.ccBy);
      expect(licenciaAbiertaDesdeCodigo('cc-by-sa'), LicenciaAbierta.ccBySa);
      expect(licenciaAbiertaDesdeCodigo('CC-BY-4.0'), LicenciaAbierta.ccBy);
      expect(licenciaAbiertaDesdeCodigo('cc_by_sa_4_0'), LicenciaAbierta.ccBySa);
      expect(licenciaAbiertaDesdeCodigo(' CC0 '), LicenciaAbierta.cc0);
    });

    test('rechaza NC, ND, todos los derechos y códigos desconocidos', () {
      for (final codigo in [
        'cc-by-nc',
        'cc-by-nc-sa',
        'cc-by-nc-nd',
        'cc-by-nd',
        'CC-BY-NC-4.0',
        'cc_by_nc_4_0',
        null,
        '',
        'all rights reserved',
        'gfdl',
        'pd',
      ]) {
        expect(licenciaAbiertaDesdeCodigo(codigo), isNull, reason: '$codigo');
      }
    });

    test('nombre y enlace de cada licencia', () {
      expect(nombreLicencia(LicenciaAbierta.ccBySa), 'CC BY-SA');
      expect(urlLicencia(LicenciaAbierta.cc0), contains('publicdomain/zero/1.0'));
      expect(urlLicencia(LicenciaAbierta.ccBy), contains('licenses/by/4.0'));
      for (final licencia in LicenciaAbierta.values) {
        expect(licenciaAbiertaDesdeCodigo(codigoLicencia(licencia)), licencia);
      }
    });

    test('los filtros de las API no piden licencias no comerciales', () {
      expect(filtroLicenciasInaturalist.contains('nc'), isFalse);
      expect(filtroLicenciasInaturalist.contains('nd'), isFalse);
      expect(licenciasRegistrosGbif.any((licencia) => licencia.contains('NC')), isFalse);
    });
  });

  group('ubicación aproximada', () {
    test('escala normal: 0,1° y 20 km', () {
      final zona = UbicacionAproximada.desde(43.26387, -2.93511);
      expect(zona.latitud, 43.3);
      expect(zona.longitud, -2.9);
      expect(zona.radioKm, 20);
      expect(zona.parametroDistanciaGbif, '43.3,-2.9,20km');
    });

    test('escala amplia: 0,5° y 75 km', () {
      final zona = UbicacionAproximada.desde(43.26387, -2.93511, escalaAmplia: true);
      expect(zona.textoCoordenadas, '43.5,-3.0');
      expect(zona.radioKm, 75);
      expect(zona.escalaAmplia, isTrue);
      expect(UbicacionAproximada.desde(43.26387, -2.93511).aEscalaAmplia(), zona);
    });

    test('nunca deja pasar la coordenada exacta ni restos de coma flotante', () {
      final zona = UbicacionAproximada.desde(0.29999, 0.1 + 0.2);
      expect(zona.textoCoordenadas, '0.3,0.3');
      expect(redondearACuadricula(0.1 + 0.2, 0.1), 0.3);
      expect(zona.parametroDistanciaGbif.contains('29999'), isFalse);
    });

    test('longitud normalizada y latitud acotada', () {
      expect(UbicacionAproximada.desde(95, 190).textoCoordenadas, '90.0,-170.0');
    });
  });
}
