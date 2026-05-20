import 'package:flutter_test/flutter_test.dart';

import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/utiles/agregados_naturaleza.dart';

/// Construye un Hallazgo mínimo con los campos relevantes para los
/// tests de agregados.
Hallazgo _hallazgo({
  required String nombreComun,
  required DateTime fecha,
  String categoria = 'animal',
  int validacion = EstadoIdentificacion.sinRevisar,
  String? confianza,
}) =>
    Hallazgo(
      fechaMs: fecha.millisecondsSinceEpoch,
      latitud: 0,
      longitud: 0,
      categoria: categoria,
      nombreComun: nombreComun,
      identificacionValidada: validacion,
      confianzaIdentificacion: confianza,
    );

void main() {
  group('calcularFenologia', () {
    test('especie con un solo registro queda fuera', () {
      final hallazgos = [
        _hallazgo(
          nombreComun: 'Tarabilla',
          fecha: DateTime(2024, 4, 14),
        ),
      ];
      expect(calcularFenologia(hallazgos), isEmpty);
    });

    test('especie con dos registros del mismo año tampoco entra', () {
      final hallazgos = [
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 4, 14)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 6, 1)),
      ];
      expect(calcularFenologia(hallazgos), isEmpty,
          reason: 'sin >=2 años distintos no hay comparativa fenológica');
    });

    test('especie con tres años calcula primer registro de cada año', () {
      final hallazgos = [
        // 2023: dos registros, el primero es 7 abr.
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2023, 4, 7)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2023, 4, 22)),
        // 2024: tres registros, primero 14 abr.
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 4, 14)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 5, 2)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 6, 11)),
        // 2025: uno, 9 abr.
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2025, 4, 9)),
      ];
      final resultado = calcularFenologia(hallazgos);
      expect(resultado.length, 1);
      final cuco = resultado.first;
      expect(cuco.etiquetaPrincipal, 'Cuco');
      expect(cuco.primerosPorAnio.map((p) => p.anio).toList(),
          [2025, 2024, 2023],
          reason: 'orden descendiente por año');
      // Día del año: 14-abr = 105 (2024 bisiesto).
      expect(cuco.primerosPorAnio[1].diaDelAnio, 105);
      // 7-abr-2023 = día 97.
      expect(cuco.primerosPorAnio[2].diaDelAnio, 97);
      // 9-abr-2025 = día 99.
      expect(cuco.primerosPorAnio[0].diaDelAnio, 99);
    });

    test('desviación del año actual respecto a media anterior', () {
      // Año 2025 (actual simulado): primer 9 abr (día 99). Anteriores:
      // 105 (2024), 97 (2023). Media = 101. Desviación = 101-99 = +2
      // → 2 días adelantado.
      final hallazgos = [
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2023, 4, 7)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2024, 4, 14)),
        _hallazgo(nombreComun: 'Cuco', fecha: DateTime(2025, 4, 9)),
      ];
      final resultado = calcularFenologia(hallazgos);
      // Sólo verificamos la lógica: la desviación está bien calculada
      // independientemente de cuál sea "el año actual" cuando corra el
      // test (el getter compara siempre primer elemento con resto).
      final desviacion = resultado.first.desviacionAnioActual;
      expect(desviacion, 2,
          reason: '101 (media de 105 y 97) - 99 (actual) = 2');
    });

    test('clave de agrupación cae a nombre científico si común está vacío',
        () {
      final hallazgos = [
        Hallazgo(
          fechaMs: DateTime(2024, 3, 1).millisecondsSinceEpoch,
          latitud: 0,
          longitud: 0,
          especie: 'Sylvia atricapilla',
        ),
        Hallazgo(
          fechaMs: DateTime(2025, 3, 5).millisecondsSinceEpoch,
          latitud: 0,
          longitud: 0,
          especie: 'Sylvia atricapilla',
        ),
      ];
      final resultado = calcularFenologia(hallazgos);
      expect(resultado.length, 1);
      expect(resultado.first.etiquetaPrincipal, 'Sylvia atricapilla');
    });
  });

  group('calcularTasaAcierto', () {
    test('sin revisados → tieneDatos == false', () {
      final hallazgos = [
        _hallazgo(nombreComun: 'X', fecha: DateTime(2024, 1, 1)),
        _hallazgo(nombreComun: 'Y', fecha: DateTime(2024, 1, 2)),
      ];
      final tasa = calcularTasaAcierto(hallazgos);
      expect(tasa.tieneDatos, isFalse);
      expect(tasa.sinRevisar, 2);
      expect(tasa.global.totalRevisado, 0);
      expect(tasa.global.porcentajeAcierto, isNull);
    });

    test('mezcla confirmadas + corregidas calcula bien la global', () {
      final hallazgos = [
        _hallazgo(
          nombreComun: 'A',
          fecha: DateTime(2024, 1, 1),
          validacion: EstadoIdentificacion.confirmada,
        ),
        _hallazgo(
          nombreComun: 'B',
          fecha: DateTime(2024, 1, 2),
          validacion: EstadoIdentificacion.confirmada,
        ),
        _hallazgo(
          nombreComun: 'C',
          fecha: DateTime(2024, 1, 3),
          validacion: EstadoIdentificacion.corregida,
        ),
        _hallazgo(
          nombreComun: 'D',
          fecha: DateTime(2024, 1, 4),
          validacion: EstadoIdentificacion.sinRevisar,
        ),
      ];
      final tasa = calcularTasaAcierto(hallazgos);
      expect(tasa.tieneDatos, isTrue);
      expect(tasa.sinRevisar, 1);
      expect(tasa.global.totalRevisado, 3);
      expect(tasa.global.confirmados, 2);
      expect(tasa.global.corregidos, 1);
      expect(tasa.global.porcentajeAcierto, closeTo(2 / 3, 0.001));
    });

    test('desglose por categoría y por confianza', () {
      final hallazgos = [
        _hallazgo(
          nombreComun: 'Aguila',
          fecha: DateTime(2024, 1, 1),
          categoria: 'animal',
          validacion: EstadoIdentificacion.confirmada,
          confianza: ConfianzaIdentificacion.segura,
        ),
        _hallazgo(
          nombreComun: 'Saltamontes',
          fecha: DateTime(2024, 1, 2),
          categoria: 'insecto',
          validacion: EstadoIdentificacion.corregida,
          confianza: ConfianzaIdentificacion.tentativa,
        ),
        _hallazgo(
          nombreComun: 'Roble',
          fecha: DateTime(2024, 1, 3),
          categoria: 'planta',
          validacion: EstadoIdentificacion.confirmada,
          confianza: ConfianzaIdentificacion.segura,
        ),
        _hallazgo(
          nombreComun: 'Margarita',
          fecha: DateTime(2024, 1, 4),
          categoria: 'planta',
          validacion: EstadoIdentificacion.corregida,
          confianza: ConfianzaIdentificacion.tentativa,
        ),
      ];
      final tasa = calcularTasaAcierto(hallazgos);
      expect(tasa.porCategoria['animal']!.porcentajeAcierto, 1.0);
      expect(tasa.porCategoria['insecto']!.porcentajeAcierto, 0.0);
      expect(tasa.porCategoria['planta']!.porcentajeAcierto, 0.5);
      // Calibración: con "segura" acierta 100%, con "tentativa" 0%.
      expect(tasa.porConfianza['segura']!.porcentajeAcierto, 1.0);
      expect(tasa.porConfianza['tentativa']!.porcentajeAcierto, 0.0);
    });

    test('confianza null no entra en el desglose por confianza', () {
      final hallazgos = [
        _hallazgo(
          nombreComun: 'X',
          fecha: DateTime(2024, 1, 1),
          validacion: EstadoIdentificacion.confirmada,
          // sin confianza
        ),
      ];
      final tasa = calcularTasaAcierto(hallazgos);
      expect(tasa.porConfianza, isEmpty);
      expect(tasa.global.totalRevisado, 1);
    });
  });
}
