import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/utiles/primeras_veces.dart';

Hallazgo _hallazgo({
  int? id,
  required DateTime fecha,
  String especie = '',
  String nombreComun = '',
  String categoria = 'ave',
  int validacion = EstadoIdentificacion.sinRevisar,
  String especieCorregida = '',
}) =>
    Hallazgo(
      id: id,
      fechaMs: fecha.millisecondsSinceEpoch,
      latitud: 43,
      longitud: -2,
      categoria: categoria,
      especie: especie,
      nombreComun: nombreComun,
      identificacionValidada: validacion,
      especieCorregida: especieCorregida,
    );

void main() {
  group('especie de un hallazgo', () {
    test('normaliza el nombre científico (mayúsculas, _ y subespecie)', () {
      final a = especieDeHallazgo(_hallazgo(fecha: DateTime(2026), especie: 'Cuculus_canorus'))!;
      final b = especieDeHallazgo(_hallazgo(fecha: DateTime(2026), especie: '  cuculus  Canorus canorus '))!;
      expect(a.clave, 'cientifico:cuculus canorus');
      expect(b.clave, a.clave);
      expect(a.nombreCientifico, 'Cuculus canorus');
    });

    test('sin nombre científico usa el común sin tildes', () {
      final especie = especieDeHallazgo(_hallazgo(fecha: DateTime(2026), nombreComun: 'Abubilla Común'))!;
      expect(especie.clave, 'comun:abubilla comun');
      expect(especie.nombreCientifico, isEmpty);
    });

    test('el común se traduce a científico si se sabe', () {
      final especie = especieDeHallazgo(_hallazgo(fecha: DateTime(2026), nombreComun: 'cuco'),
          cientificoPorNombreComun: (nombre) => nombre == 'cuco' ? 'Cuculus canorus' : null)!;
      expect(especie.clave, 'cientifico:cuculus canorus');
    });

    test('sin ningún nombre no cuenta', () {
      expect(especieDeHallazgo(_hallazgo(fecha: DateTime(2026))), isNull);
    });

    test('una identificación corregida cuenta como la especie corregida', () {
      final especie = especieDeHallazgo(_hallazgo(
        fecha: DateTime(2026),
        especie: 'Turdus merula',
        validacion: EstadoIdentificacion.corregida,
        especieCorregida: 'Turdus philomelos',
      ))!;
      expect(especie.clave, 'cientifico:turdus philomelos');
    });
  });

  group('primeras veces', () {
    final hallazgos = [
      _hallazgo(id: 1, fecha: DateTime(2025, 4, 2, 8), especie: 'Cuculus canorus', nombreComun: 'Cuco'),
      _hallazgo(id: 2, fecha: DateTime(2025, 4, 10), especie: 'Cuculus canorus'),
      _hallazgo(id: 3, fecha: DateTime(2026, 3, 23, 9), especie: 'Cuculus canorus', nombreComun: 'Cuco'),
      // Varias el mismo día: cuenta la más temprana.
      _hallazgo(id: 4, fecha: DateTime(2026, 3, 23, 7), especie: 'Cuculus canorus', nombreComun: 'Cuco'),
      _hallazgo(id: 5, fecha: DateTime(2026, 5, 1), nombreComun: 'Golondrina'),
      _hallazgo(id: 6, fecha: DateTime(2023, 5, 3), nombreComun: 'golondrina'),
      _hallazgo(id: 7, fecha: DateTime(2026, 6, 1)),
    ];

    test('la primera de cada especie y año', () {
      final primeras = calcularPrimerasVeces(hallazgos);
      expect(primeras.keys, containsAll(['cientifico:cuculus canorus', 'comun:golondrina']));
      expect(primeras.length, 2);
      final cuco = primeras['cientifico:cuculus canorus']!;
      expect(cuco.porAnio[2025]!.idHallazgo, 1);
      expect(cuco.porAnio[2026]!.idHallazgo, 4);
    });

    test('misma hora exacta: gana el id menor', () {
      final primeras = calcularPrimerasVeces([
        _hallazgo(id: 9, fecha: DateTime(2026, 3, 1, 8), especie: 'Upupa epops'),
        _hallazgo(id: 8, fecha: DateTime(2026, 3, 1, 8), especie: 'Upupa epops'),
      ]);
      expect(primeras['cientifico:upupa epops']!.porAnio[2026]!.idHallazgo, 8);
    });

    test('comparación con el año anterior: adelanto en días', () {
      final primeras = calcularPrimerasVeces(hallazgos);
      final comparacion = compararConAnioAnterior(primeras['cientifico:cuculus canorus']!, 2026)!;
      expect(comparacion.anioAnterior, 2025);
      expect(comparacion.diasDiferencia, -10);
      expect(comparacion.esAdelanto, isTrue);
    });

    test('años sin datos: compara con el anterior que tenga', () {
      final primeras = calcularPrimerasVeces(hallazgos);
      final comparacion = compararConAnioAnterior(primeras['comun:golondrina']!, 2026)!;
      expect(comparacion.anioAnterior, 2023);
      expect(comparacion.diasDiferencia, -2);
    });

    test('sin año anterior no hay comparación', () {
      final primeras = calcularPrimerasVeces(hallazgos);
      expect(compararConAnioAnterior(primeras['cientifico:cuculus canorus']!, 2025), isNull);
      expect(compararConAnioAnterior(primeras['cientifico:cuculus canorus']!, 2024), isNull);
    });

    test('diferencia de calendario con años bisiestos', () {
      // 1 de marzo de 2025 frente al 29 de febrero de 2024: se lleva al 1 de
      // marzo de 2025 → mismo día.
      expect(diasDeDiferenciaEnElCalendario(DateTime(2025, 3, 1), DateTime(2024, 2, 29)), 0);
      expect(diasDeDiferenciaEnElCalendario(DateTime(2024, 3, 1), DateTime(2023, 3, 1)), 0);
      expect(diasDeDiferenciaEnElCalendario(DateTime(2026, 4, 12, 23), DateTime(2025, 4, 2, 1)), 10);
    });

    test('primeras del año ordenadas y años', () {
      final primeras = calcularPrimerasVeces(hallazgos);
      expect(aniosConPrimerasVeces(primeras), [2026, 2025, 2023]);
      final de2026 = primerasVecesDelAnio(primeras, 2026);
      expect(de2026.map((primera) => primera.idHallazgo), [4, 5]);
      expect(primerasVecesDelAnio(primeras, 2024), isEmpty);
    });

    test('sin hallazgos', () {
      expect(calcularPrimerasVeces(const []), isEmpty);
    });
  });

  group('primera vez al guardar', () {
    final existentes = [
      _hallazgo(id: 1, fecha: DateTime(2025, 4, 2), especie: 'Cuculus canorus'),
      _hallazgo(id: 2, fecha: DateTime(2026, 4, 5), especie: 'Upupa epops'),
    ];

    test('primera del año, con comparación', () {
      final nueva = primeraVezAlGuardar(
          _hallazgo(fecha: DateTime(2026, 3, 23), especie: 'Cuculus canorus'), existentes)!;
      expect(nueva.primeraVez.anio, 2026);
      expect(nueva.comparacion!.diasDiferencia, -10);
    });

    test('no es la primera si ya había antes ese año', () {
      expect(primeraVezAlGuardar(_hallazgo(fecha: DateTime(2026, 4, 6), especie: 'Upupa epops'), existentes), isNull);
    });

    test('con fecha anterior a la que había ese año sí lo es', () {
      final nueva = primeraVezAlGuardar(_hallazgo(fecha: DateTime(2026, 4, 1), especie: 'Upupa epops'), existentes)!;
      expect(nueva.comparacion, isNull);
    });

    test('especie nueva del todo: primera sin comparación', () {
      final nueva = primeraVezAlGuardar(_hallazgo(fecha: DateTime(2026, 4, 1), nombreComun: 'Mirlo'), existentes)!;
      expect(nueva.primeraVez.nombreComun, 'Mirlo');
      expect(nueva.comparacion, isNull);
    });

    test('sin especie no hay aviso', () {
      expect(primeraVezAlGuardar(_hallazgo(fecha: DateTime(2026, 4, 1)), existentes), isNull);
    });
  });
}
