import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/bufer_ultimos_segundos.dart';

List<double> rampa(int desde, int cuantas) =>
    [for (var valor = desde; valor < desde + cuantas; valor++) valor.toDouble()];

void main() {
  group('BuferCircularAudio', () {
    test('antes de llenarse guarda todo', () {
      final bufer = BuferCircularAudio(10)..anadir(rampa(0, 4));
      expect(bufer.muestrasTotales, 4);
      expect(bufer.muestrasGuardadas, 4);
      expect(bufer.primeraMuestraDisponible, 0);
      expect(bufer.ultimas(10), [0, 1, 2, 3]);
    });

    test('al dar la vuelta conserva solo lo último y en orden', () {
      final bufer = BuferCircularAudio(10);
      for (var bloque = 0; bloque < 5; bloque++) {
        bufer.anadir(rampa(bloque * 7, 7));
      }
      expect(bufer.muestrasTotales, 35);
      expect(bufer.primeraMuestraDisponible, 25);
      expect(bufer.ultimas(10), rampa(25, 10));
      expect(bufer.ultimas(3), [32, 33, 34]);
      expect(bufer.extraer(27, 30), [27, 28, 29]);
    });

    test('un bloque más largo que el búfer', () {
      final bufer = BuferCircularAudio(5)
        ..anadir(rampa(0, 3))
        ..anadir(rampa(3, 12));
      expect(bufer.muestrasTotales, 15);
      expect(bufer.ultimas(5), rampa(10, 5));
    });

    test('lo que ya salió o no ha llegado da null', () {
      final bufer = BuferCircularAudio(10)..anadir(rampa(0, 25));
      expect(bufer.extraer(10, 20), isNull);
      expect(bufer.extraer(20, 26), isNull);
      expect(bufer.extraer(20, 20), isNull);
      expect(bufer.extraer(15, 25), rampa(15, 10));
    });

    test('vaciar', () {
      final bufer = BuferCircularAudio(4)
        ..anadir(rampa(0, 6))
        ..vaciar();
      expect(bufer.muestrasTotales, 0);
      expect(bufer.ultimas(4), isEmpty);
    });

    test('capacidad no positiva', () {
      expect(() => BuferCircularAudio(0), throwsRangeError);
    });
  });

  group('RegistroTramosAnalizados', () {
    test('trozos solapados y limpios se juntan', () {
      final registro = RegistroTramosAnalizados()
        ..registrar(0, 100, conVozHumana: false)
        ..registrar(50, 150, conVozHumana: false)
        ..registrar(100, 200, conVozHumana: false);
      expect(registro.tramosLimpios(), [(inicio: 0, fin: 200)]);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 80, primeraDisponible: 0), (inicio: 120, fin: 200));
    });

    test('nada de un trozo con voz entra, aunque se solape con uno limpio', () {
      final registro = RegistroTramosAnalizados()
        ..registrar(0, 100, conVozHumana: false)
        ..registrar(50, 150, conVozHumana: true)
        ..registrar(100, 200, conVozHumana: false);
      expect(registro.tramosLimpios(), [(inicio: 0, fin: 50), (inicio: 150, fin: 200)]);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 0), (inicio: 150, fin: 200));
    });

    test('si lo último tenía voz, se usa el último tramo limpio anterior', () {
      final registro = RegistroTramosAnalizados()
        ..registrar(0, 100, conVozHumana: false)
        ..registrar(80, 180, conVozHumana: true);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 0), (inicio: 0, fin: 80));
    });

    test('con huecos sin analizar, el último tramo continuo', () {
      final registro = RegistroTramosAnalizados()
        ..registrar(0, 100, conVozHumana: false)
        ..registrar(150, 250, conVozHumana: false);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 0), (inicio: 150, fin: 250));
    });

    test('se recorta a lo que queda en el búfer', () {
      final registro = RegistroTramosAnalizados()..registrar(0, 100, conVozHumana: false);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 60), (inicio: 60, fin: 100));
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 100), isNull);
    });

    test('sin nada limpio, null; olvidar lo viejo', () {
      final registro = RegistroTramosAnalizados()..registrar(0, 100, conVozHumana: true);
      expect(registro.ultimoTramoLimpio(maximoMuestras: 1000, primeraDisponible: 0), isNull);
      registro
        ..registrar(100, 200, conVozHumana: false)
        ..olvidarAnterioresA(100);
      expect(registro.tramosLimpios(), [(inicio: 100, fin: 200)]);
      registro.vaciar();
      expect(registro.tramosLimpios(), isEmpty);
    });
  });
}
