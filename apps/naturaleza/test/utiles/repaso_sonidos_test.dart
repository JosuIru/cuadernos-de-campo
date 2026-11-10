import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/utiles/repaso_sonidos.dart';

Hallazgo _hallazgo(int id, String especie, {String? audio, String categoria = 'ave', String nombreComun = ''}) =>
    Hallazgo(
      id: id,
      fechaMs: DateTime(2026, 4, id).millisecondsSinceEpoch,
      latitud: 43,
      longitud: -2,
      categoria: categoria,
      especie: especie,
      nombreComun: nombreComun,
      rutaAudio: audio,
    );

void main() {
  final hallazgos = [
    _hallazgo(1, 'Turdus merula', audio: '/a/1.wav'),
    _hallazgo(2, 'Turdus merula', audio: '/a/2.wav'),
    _hallazgo(3, 'Erithacus rubecula', audio: '/a/3.wav'),
    _hallazgo(4, 'Cuculus canorus', audio: '/a/4.wav'),
    _hallazgo(5, 'Bufo spinosus', audio: '/a/5.wav', categoria: 'anfibio'),
    _hallazgo(6, 'Parus major'),
    _hallazgo(7, 'Fringilla coelebs'),
    _hallazgo(8, '', audio: '/a/8.wav'),
    _hallazgo(9, 'Sitta europaea', audio: '/a/borrado.wav'),
  ];

  group('tarjetas', () {
    test('solo hallazgos con clip, especie y fichero', () {
      final tarjetas = tarjetasDesdeHallazgos(hallazgos, existeAudio: (ruta) => !ruta.contains('borrado'));
      expect(tarjetas.map((tarjeta) => tarjeta.idHallazgo), [1, 2, 3, 4, 5]);
      expect(especiesConClip(tarjetas), 4);
    });

    test('pocas especies con clip', () {
      final tarjetas = tarjetasDesdeHallazgos(hallazgos.take(3));
      expect(especiesConClip(tarjetas) < especiesMinimasRepaso, isTrue);
    });
  });

  group('opciones', () {
    final tarjetas = tarjetasDesdeHallazgos(hallazgos);
    final especies = especiesDelCuaderno(hallazgos);
    final clavesConClip = {for (final tarjeta in tarjetas) tarjeta.claveEspecie};

    test('4 opciones distintas con la correcta', () {
      for (var semilla = 0; semilla < 20; semilla++) {
        final opciones = opcionesParaTarjeta(tarjetas.first, especies, clavesConClip, Random(semilla));
        expect(opciones.length, opcionesPorPregunta);
        expect(opciones.toSet().length, opcionesPorPregunta);
        expect(opciones.where((opcion) => opcion.claveEspecie == tarjetas.first.claveEspecie).length, 1);
      }
    });

    test('distractores del mismo grupo y con clip primero', () {
      final opciones = opcionesParaTarjeta(tarjetas.first, especies, clavesConClip, Random(1));
      final claves = opciones.map((opcion) => opcion.claveEspecie).toSet();
      // Mirlo correcto; petirrojo y cuco (aves con clip) siempre; el cuarto,
      // un ave sin clip (carbonero, pinzón o trepador) antes que el sapo.
      expect(claves, containsAll(['cientifico:erithacus rubecula', 'cientifico:cuculus canorus']));
      expect(claves.contains('cientifico:bufo spinosus'), isFalse);
    });

    test('con pocas especies devuelve las que hay', () {
      final pocas = especiesDelCuaderno(hallazgos.take(3));
      final opciones = opcionesParaTarjeta(tarjetas.first, pocas, clavesConClip, Random(1));
      expect(opciones.length, 2);
    });
  });

  group('Leitner', () {
    final ahora = DateTime(2026, 4, 20, 10);

    test('acierto sube de caja; fallo vuelve a la 1', () {
      var estado = EstadoRepaso.vacio;
      expect(estado.estadoDe(1).caja, 1);
      expect(estado.tocaRepasar(1, ahora), isTrue);
      estado = estado.conRespuesta(1, acierto: true, ahora: ahora);
      expect(estado.estadoDe(1).caja, 2);
      expect(estado.estadoDe(1).proximoRepasoMs, ahora.add(const Duration(days: 2)).millisecondsSinceEpoch);
      expect(estado.tocaRepasar(1, ahora), isFalse);
      for (var vez = 0; vez < 10; vez++) {
        estado = estado.conRespuesta(1, acierto: true, ahora: ahora);
      }
      expect(estado.estadoDe(1).caja, cajaMaxima);
      estado = estado.conRespuesta(1, acierto: false, ahora: ahora);
      expect(estado.estadoDe(1).caja, 1);
      expect(estado.estadoDe(1).proximoRepasoMs, ahora.add(const Duration(days: 1)).millisecondsSinceEpoch);
    });

    test('JSON de ida y vuelta, y JSON roto', () {
      final estado = EstadoRepaso.vacio
          .conRespuesta(1, acierto: true, ahora: ahora)
          .conRespuesta(3, acierto: false, ahora: ahora);
      final leido = EstadoRepaso.desdeJson(estado.aJson());
      expect(leido.estadoDe(1).caja, 2);
      expect(leido.estadoDe(3).caja, 1);
      expect(EstadoRepaso.desdeJson('no es json').porHallazgo, isEmpty);
      expect(EstadoRepaso.desdeJson('{"x":{"caja":2},"4":{"caja":9,"proximo_ms":1},"5":{"caja":3,"proximo_ms":7}}')
          .porHallazgo
          .keys, [5]);
    });

    test('limpia tarjetas que ya no existen', () {
      final estado = EstadoRepaso.vacio
          .conRespuesta(1, acierto: true, ahora: ahora)
          .conRespuesta(2, acierto: true, ahora: ahora);
      expect(estado.soloDe([2]).porHallazgo.keys, [2]);
    });

    test('ronda: primero las pendientes; si no hay, las más próximas', () {
      final tarjetas = tarjetasDesdeHallazgos(hallazgos);
      var estado = EstadoRepaso.vacio;
      for (final tarjeta in tarjetas) {
        estado = estado.conRespuesta(tarjeta.idHallazgo, acierto: true, ahora: ahora);
      }
      estado = estado.conRespuesta(3, acierto: false, ahora: ahora.subtract(const Duration(days: 3)));
      expect(tarjetasPendientes(tarjetas, estado, ahora), 1);
      final ronda = tarjetasParaRonda(tarjetas, estado, ahora, azar: Random(1));
      expect(ronda.map((tarjeta) => tarjeta.idHallazgo), [3]);
      final rondaCompleta =
          tarjetasParaRonda(tarjetas, estado, ahora, maximo: 3, aunqueNoToquen: true, azar: Random(1));
      expect(rondaCompleta.length, 3);
      expect(rondaCompleta.first.idHallazgo, 3);
    });
  });
}
