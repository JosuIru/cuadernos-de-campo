import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/remuestreo_audio.dart';
import 'package:naturaleza_flutter/sonido/ventanas_audio.dart';

Float32List ondaSeno(double frecuenciaHz, int frecuenciaMuestreoHz, int numeroMuestras) {
  final muestras = Float32List(numeroMuestras);
  for (var indice = 0; indice < numeroMuestras; indice++) {
    muestras[indice] = math.sin(2 * math.pi * frecuenciaHz * indice / frecuenciaMuestreoHz);
  }
  return muestras;
}

double valorEficaz(List<double> muestras, int primerIndice, int ultimoIndice) {
  var sumaCuadrados = 0.0;
  for (var indice = primerIndice; indice < ultimoIndice; indice++) {
    sumaCuadrados += muestras[indice] * muestras[indice];
  }
  return math.sqrt(sumaCuadrados / (ultimoIndice - primerIndice));
}

Float32List rampaDesde(double valorInicial, int numeroMuestras) =>
    Float32List.fromList([for (var indice = 0; indice < numeroMuestras; indice++) valorInicial + indice]);

void main() {
  group('remuestrearConPasoBajo', () {
    test('pasa de 48 kHz a 32 kHz conservando un tono de 1 kHz', () {
      final salida = remuestrearConPasoBajo(ondaSeno(1000, 48000, 4800), 48000, 32000);
      expect(salida.length, 3200);
      final esperada = ondaSeno(1000, 32000, 3200);
      var errorMaximo = 0.0;
      // Lejos de los bordes, donde el filtro no tiene audio a un lado.
      for (var indice = 100; indice < 3100; indice++) {
        errorMaximo = math.max(errorMaximo, (salida[indice] - esperada[indice]).abs());
      }
      expect(errorMaximo, lessThan(0.01));
    });

    test('elimina lo que queda por encima de la nueva frecuencia de Nyquist (antialias)', () {
      final salida = remuestrearConPasoBajo(ondaSeno(20000, 48000, 9600), 48000, 32000);
      // Sin filtro, este tono de 20 kHz aparecería como uno de 12 kHz.
      expect(valorEficaz(salida, 200, salida.length - 200), lessThan(0.01));
    });

    test('funciona también desde 44,1 kHz y respeta la longitud pedida', () {
      final salida =
          remuestrearConPasoBajo(ondaSeno(2000, 44100, 44100), 44100, 32000, longitudSalida: 32000);
      expect(salida.length, 32000);
      expect(valorEficaz(salida, 1000, 31000), closeTo(math.sqrt1_2, 0.005));
    });

    test('rellena con ceros si falta audio y copia si la frecuencia ya es la buena', () {
      final rellenada = remuestrearConPasoBajo(
          Float32List(10)..fillRange(0, 10, 0.5), 32000, 32000,
          longitudSalida: 20);
      expect(rellenada.sublist(0, 10), everyElement(0.5));
      expect(rellenada.sublist(10), everyElement(0));
    });

    test('rechaza frecuencias no positivas', () {
      expect(() => remuestrearConPasoBajo([0, 1], 0, 32000), throwsRangeError);
    });
  });

  group('RecolectorVentanasAudio', () {
    test('no entrega nada hasta tener una ventana completa', () {
      final recolector = RecolectorVentanasAudio(10);
      recolector.anadirMuestras(rampaDesde(0, 6));
      expect(recolector.tomarVentanaSiLista(5), isNull);
      recolector.anadirMuestras(rampaDesde(6, 4));
      expect(recolector.tomarVentanaSiLista(5), rampaDesde(0, 10));
    });

    test('solapa según el salto pedido y entrega las muestras en orden', () {
      final recolector = RecolectorVentanasAudio(10);
      recolector.anadirMuestras(rampaDesde(0, 10));
      expect(recolector.tomarVentanaSiLista(5), isNotNull);
      recolector.anadirMuestras(rampaDesde(10, 3));
      expect(recolector.tomarVentanaSiLista(5), isNull);
      recolector.anadirMuestras(rampaDesde(13, 2));
      expect(recolector.tomarVentanaSiLista(5), rampaDesde(5, 10));
      expect(recolector.muestrasRecibidasTotales, 15);
    });

    test('si se ha retrasado, salta a la ventana más reciente', () {
      final recolector = RecolectorVentanasAudio(4);
      recolector.anadirMuestras(rampaDesde(0, 4));
      recolector.tomarVentanaSiLista(2);
      recolector.anadirMuestras(rampaDesde(4, 7));
      expect(recolector.tomarVentanaSiLista(2), [7, 8, 9, 10]);
      expect(recolector.tomarVentanaSiLista(2), isNull);
    });

    test('se vacía con reiniciar', () {
      final recolector = RecolectorVentanasAudio(4);
      recolector.anadirMuestras(rampaDesde(0, 4));
      recolector.reiniciar();
      expect(recolector.tomarVentanaSiLista(1), isNull);
      expect(recolector.muestrasRecibidasTotales, 0);
    });

    test('rechaza ventanas sin muestras', () {
      expect(() => RecolectorVentanasAudio(0), throwsRangeError);
    });
  });

  test('elegirSaltoSegundos solapa mientras el análisis es rápido y deja de hacerlo si es lento', () {
    expect(elegirSaltoSegundos(null), saltoConSolapeSegundos);
    expect(elegirSaltoSegundos(400), saltoConSolapeSegundos);
    expect(elegirSaltoSegundos(2000), saltoSinSolapeSegundos);
  });

  test('nivelRmsDecibelios da 0 dBFS con amplitud 1 y un suelo para el silencio', () {
    expect(nivelRmsDecibelios([1, -1, 1, -1]), closeTo(0, 1e-6));
    expect(nivelRmsDecibelios(Float32List(8)), closeTo(-200, 1e-9));
  });

  test('pcm16ABloqueFlotante lee PCM de 16 bits little-endian', () {
    final bytes = Uint8List.fromList([0x00, 0x80, 0xff, 0x7f, 0x00, 0x00, 0x01]);
    final muestras = pcm16ABloqueFlotante(bytes);
    expect(muestras.length, 3);
    expect(muestras[0], -1.0);
    expect(muestras[1], closeTo(1.0, 1e-4));
    expect(muestras[2], 0);
  });
}
