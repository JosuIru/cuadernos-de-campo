import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/calidad_audio.dart';

const double frecuenciaMuestreo = 48000;
const int segundos = 3;
const int numeroMuestras = 48000 * segundos;

List<double> seno(double frecuenciaHz, double amplitud, {int muestras = numeroMuestras}) => [
      for (var indice = 0; indice < muestras; indice++)
        amplitud * math.sin(2 * math.pi * frecuenciaHz * indice / frecuenciaMuestreo),
    ];

/// Ruido blanco filtrado a graves (paso bajo) con semilla fija.
List<double> ruidoGrave(double corteHz, double amplitud, {int semilla = 7}) {
  final aleatorio = math.Random(semilla);
  final filtro = FiltroBiquad.pasoBajo(frecuenciaMuestreo, corteHz);
  final filtro2 = FiltroBiquad.pasoBajo(frecuenciaMuestreo, corteHz);
  return [
    for (var indice = 0; indice < numeroMuestras; indice++)
      amplitud * filtro2.procesar(filtro.procesar(aleatorio.nextDouble() * 2 - 1)),
  ];
}

EvaluacionCalidad evaluar(List<double> senal) {
  final analizador = AnalizadorCalidadAudio(frecuenciaMuestreo);
  // Por bloques, como llega del micrófono.
  for (var inicio = 0; inicio < senal.length; inicio += 2048) {
    analizador.procesar(senal.sublist(inicio, math.min(senal.length, inicio + 2048)));
  }
  return analizador.evaluar();
}

void main() {
  test('filtros: el paso bajo deja los graves y quita los agudos', () {
    double rmsTrasFiltro(FiltroBiquad filtro, double frecuenciaHz) {
      final senal = seno(frecuenciaHz, 1, muestras: 48000);
      var suma = 0.0;
      for (var indice = 0; indice < senal.length; indice++) {
        final salida = filtro.procesar(senal[indice]);
        if (indice > 4800) suma += salida * salida;
      }
      return math.sqrt(suma / (senal.length - 4800));
    }

    expect(rmsTrasFiltro(FiltroBiquad.pasoBajo(frecuenciaMuestreo, 1000), 100), closeTo(math.sqrt1_2, 0.02));
    expect(rmsTrasFiltro(FiltroBiquad.pasoBajo(frecuenciaMuestreo, 1000), 8000), lessThan(0.02));
    expect(rmsTrasFiltro(FiltroBiquad.pasoAlto(frecuenciaMuestreo, 1000), 100), lessThan(0.02));
    // En el corte, −3 dB.
    expect(rmsTrasFiltro(FiltroBiquad.pasoBajo(frecuenciaMuestreo, 1000), 1000), closeTo(0.5, 0.02));
  });

  test('un canto limpio (3 kHz) no da avisos', () {
    final evaluacion = evaluar(seno(3000, 0.1));
    expect(evaluacion.avisos, isEmpty);
    expect(evaluacion.nivelDecibelios, closeTo(-23, 0.5));
  });

  test('saturación: un seno recortado', () {
    final recortado = seno(2000, 1.6).map((muestra) => muestra.clamp(-1.0, 1.0)).toList();
    final evaluacion = evaluar(recortado);
    expect(evaluacion.avisos, contains(AvisoCalidad.saturacion));
    expect(evaluacion.principal, AvisoCalidad.saturacion);
  });

  test('viento: retumbo grave a rachas', () {
    final retumbo = ruidoGrave(80, 3);
    final conRachas = [
      for (var indice = 0; indice < retumbo.length; indice++)
        // Rachas de ~1,3 s que van de casi nada a fuerte.
        retumbo[indice] * (0.15 + 0.85 * math.pow(math.sin(math.pi * indice / (48000 * 1.3)), 2)),
    ];
    final evaluacion = evaluar(conRachas);
    expect(evaluacion.fraccionMuyGraves, greaterThan(fraccionMuyGravesViento));
    expect(evaluacion.avisos, contains(AvisoCalidad.viento));
    expect(evaluacion.avisos, isNot(contains(AvisoCalidad.trafico)));
  });

  test('tráfico: ruido grave estable y fuerte', () {
    final evaluacion = evaluar(ruidoGrave(400, 1));
    expect(evaluacion.avisos, contains(AvisoCalidad.trafico));
    expect(evaluacion.avisos, isNot(contains(AvisoCalidad.viento)));
  });

  test('un canto encima de un tráfico flojo no se marca como tráfico', () {
    final trafico = ruidoGrave(400, 0.05);
    final canto = seno(3000, 0.1);
    final evaluacion =
        evaluar([for (var indice = 0; indice < numeroMuestras; indice++) trafico[indice] + canto[indice]]);
    expect(evaluacion.avisos, isNot(contains(AvisoCalidad.trafico)));
  });

  test('señal débil', () {
    final evaluacion = evaluar(seno(3000, 0.0005));
    expect(evaluacion.avisos, {AvisoCalidad.senalDebil});
  });

  test('sin datos no hay avisos; las tramas se cierran cada 0,1 s y se avisa del nivel de la banda', () {
    expect(evaluarTramasCalidad(const []).avisos, isEmpty);
    final niveles = <double>[];
    final analizador = AnalizadorCalidadAudio(frecuenciaMuestreo,
        alCerrarTrama: (trama) => niveles.add(trama.nivelBandaCantoDecibelios));
    analizador.procesar(seno(3000, 0.1, muestras: 48000));
    expect(niveles.length, 10);
    // −23 dBFS de un seno de 0,1 dentro de la banda.
    expect(niveles.last, closeTo(-23, 1));
    expect(analizador.tramas.length, 10);
    analizador.reiniciar();
    expect(analizador.tramas, isEmpty);
  });
}
