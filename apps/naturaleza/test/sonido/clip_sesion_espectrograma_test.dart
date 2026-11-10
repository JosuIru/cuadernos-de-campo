import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/clasificacion_sonido.dart';
import 'package:naturaleza_flutter/sonido/clip_audio.dart';
import 'package:naturaleza_flutter/sonido/espectrograma_mel.dart';
import 'package:naturaleza_flutter/sonido/sesion_escucha.dart';

Int16List rampa(int desde, int numero) =>
    Int16List.fromList([for (var indice = 0; indice < numero; indice++) desde + indice]);

void main() {
  group('clip de audio', () {
    test('flotanteAPcm16 escala y recorta', () {
      expect(flotanteAPcm16([0, 1, -1, 2, -2, 0.5]), [0, 32767, -32767, 32767, -32768, 16384]);
    });

    test('componerClip une la parte nueva del trozo anterior con el actual', () {
      // Trozos de 10 muestras con salto de 5: el anterior cubre 0-9, el actual 5-14.
      final clip = componerClip(
          trozoActual: rampa(5, 10), trozoAnterior: rampa(0, 10), separacionMuestras: 5);
      expect(clip, rampa(0, 15));
    });

    test('componerClip sin solape da dos trozos seguidos (10 s como máximo)', () {
      final clip = componerClip(
          trozoActual: rampa(10, 10), trozoAnterior: rampa(0, 10), separacionMuestras: 10);
      expect(clip, rampa(0, 20));
    });

    test('componerClip deja solo el actual si no hay anterior o se saltaron trozos', () {
      expect(componerClip(trozoActual: rampa(5, 10)), rampa(5, 10));
      expect(
          componerClip(trozoActual: rampa(30, 10), trozoAnterior: rampa(0, 10), separacionMuestras: 30),
          rampa(30, 10));
      expect(
          componerClip(trozoActual: rampa(5, 10), trozoAnterior: rampa(0, 10), separacionMuestras: 0),
          rampa(5, 10));
    });

    test('separacionEnFrecuenciaModelo pasa de 48 kHz a 32 kHz', () {
      expect(separacionEnFrecuenciaModelo(120000, 48000, 32000), 80000);
      expect(separacionEnFrecuenciaModelo(120000, 0, 32000), 0);
    });

    test('codificarWavMono16 escribe una cabecera RIFF válida', () {
      final wav = codificarWavMono16(Int16List.fromList([0, -1, 32767]), 32000);
      final datos = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(datos.getUint32(4, Endian.little), 36 + 6);
      expect(datos.getUint16(20, Endian.little), 1);
      expect(datos.getUint16(22, Endian.little), 1);
      expect(datos.getUint32(24, Endian.little), 32000);
      expect(datos.getUint32(28, Endian.little), 64000);
      expect(datos.getUint16(34, Endian.little), 16);
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(datos.getUint32(40, Endian.little), 6);
      expect(datos.getInt16(46, Endian.little), -1);
      expect(datos.getInt16(48, Endian.little), 32767);
      expect(wav.length, 50);
    });
  });

  group('SesionEscucha', () {
    final inicio = DateTime(2026, 5, 1, 7);

    test('cuenta cada especie y se queda con el clip de su mejor puntuación', () {
      final sesion = SesionEscucha();
      sesion.registrarTrozo(
        especiesMostradas: const [ClaseClasificada(indiceClase: 0, puntuacion: 8)],
        momento: inicio,
        clip: rampa(0, 3),
      );
      sesion.registrarTrozo(
        especiesMostradas: const [
          ClaseClasificada(indiceClase: 0, puntuacion: 11, puntuacionModelo: 13),
          ClaseClasificada(indiceClase: 1, puntuacion: 9),
        ],
        momento: inicio.add(const Duration(seconds: 5)),
        clip: rampa(100, 3),
      );
      sesion.registrarTrozo(
        especiesMostradas: const [ClaseClasificada(indiceClase: 0, puntuacion: 7.5)],
        momento: inicio.add(const Duration(seconds: 10)),
        clip: rampa(200, 3),
      );
      final mirlo = sesion.especie(0)!;
      expect(mirlo.vecesOida, 3);
      expect(mirlo.mejorPuntuacion, 11);
      expect(mirlo.mejorPuntuacionModelo, 13);
      expect(mirlo.clipMejor, rampa(100, 3));
      expect(mirlo.momentoMejor, inicio.add(const Duration(seconds: 5)));
      expect(mirlo.ultimaVez, inicio.add(const Duration(seconds: 10)));
      expect(sesion.especiesPorPuntuacion.map((especie) => especie.indiceClase), [0, 1]);
      expect(sesion.trozosAnalizados, 3);
    });

    test('los trozos con voz humana solo se cuentan', () {
      final sesion = SesionEscucha()..registrarTrozoConVozHumana();
      expect(sesion.trozosAnalizados, 1);
      expect(sesion.trozosConVozHumana, 1);
      expect(sesion.numeroEspecies, 0);
    });

    test('no guarda más clips del tope en memoria', () {
      final sesion = SesionEscucha();
      for (var indiceClase = 0; indiceClase < maximoEspeciesConClip + 2; indiceClase++) {
        sesion.registrarTrozo(
          especiesMostradas: [ClaseClasificada(indiceClase: indiceClase, puntuacion: 8)],
          momento: inicio,
          clip: rampa(0, 2),
        );
      }
      final conClip =
          sesion.especiesPorPuntuacion.where((especie) => especie.clipMejor != null).length;
      expect(conClip, maximoEspeciesConClip);
      expect(sesion.numeroEspecies, maximoEspeciesConClip + 2);
    });
  });

  group('espectrograma', () {
    test('rangoPorPercentiles ignora los extremos y los valores no finitos', () {
      final valores = [for (var indice = 0; indice < 1000; indice++) indice.toDouble()];
      valores[0] = double.nan;
      final rango = rangoPorPercentiles(valores);
      expect(rango.minimo, closeTo(51, 0.5));
      expect(rango.maximo, closeTo(994, 0.5));
    });

    test('rangoPorPercentiles no devuelve un rango vacío', () {
      final plano = rangoPorPercentiles([2, 2, 2, 2]);
      expect([plano.minimo, plano.maximo], [2, 3]);
      final vacio = rangoPorPercentiles(const []);
      expect([vacio.minimo, vacio.maximo], [0, 1]);
    });

    test('pone el tiempo en horizontal y los graves abajo', () {
      // Paleta de grises: el nivel es el propio color.
      final grises = Uint8List.fromList([for (var entrada = 0; entrada < 256 * 3; entrada++) entrada ~/ 3]);
      // 2 tramas × 3 bandas: solo la banda más grave de la segunda trama suena.
      final espectrograma = <double>[0, 0, 0, 10, 0, 0];
      final pixeles = Uint8List(2 * 3 * 4);
      pintarEspectrogramaMel(espectrograma, 2, 3, pixeles, grises);
      int nivelEn(int columna, int fila) => pixeles[(fila * 2 + columna) * 4];
      expect(nivelEn(1, 2), 255);
      expect(nivelEn(0, 2), 0);
      expect(nivelEn(1, 0), 0);
      expect(pixeles[3], 255);
      expect(paletaEspectrograma().length, 768);
    });
  });
}
