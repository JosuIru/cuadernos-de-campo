import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/sonidos_propios.dart';

/// Embeddings sintéticos con la distribución medida en Perch 2.0 real (ver
/// el Laboratorio): centrados (sonidos distintos dan coseno ≈ 0) y, dentro
/// de un sonido, un ruido tal que dos muestras dan ≈ 0,75.
class MundoSintetico {
  final math.Random aleatorio;
  MundoSintetico(int semilla) : aleatorio = math.Random(semilla);

  double _centrado() => aleatorio.nextDouble() * 2 - 1;

  Float32List perfil() =>
      Float32List.fromList([for (var i = 0; i < dimensionesEmbeddingPerch; i++) _centrado()]);

  Float32List muestraDe(Float32List perfil, {double amplitudRuido = 0.58}) =>
      Float32List.fromList([for (var i = 0; i < perfil.length; i++) perfil[i] + _centrado() * amplitudRuido]);
}

final creado = DateTime.utc(2026, 11, 10, 8);
final perro = SonidoPropio(id: 1, nombre: 'Mi perro', esFondo: false, creado: creado);
final carabo = SonidoPropio(id: 2, nombre: 'El cárabo del roble', esFondo: false, creado: creado);
final fondo = SonidoPropio(id: 3, nombre: 'Fondo', esFondo: true, creado: creado);

EjemploSonidoPropio ejemplo(int id, int idSonido, Float32List embedding, {String version = 'europa-1'}) =>
    EjemploSonidoPropio(
        id: id, idSonido: idSonido, creado: creado, versionModelo: version, embedding: embedding);

void main() {
  group('similitud coseno', () {
    test('1 con proporcionales, 0 con ortogonales y con el vector nulo', () {
      expect(similitudCoseno([1, 2, 3], [2, 4, 6]), closeTo(1, 1e-6));
      expect(similitudCoseno([1, 0], [0, 5]), closeTo(0, 1e-6));
      expect(similitudCoseno([1, 1], [-1, -1]), closeTo(-1, 1e-6));
      expect(similitudCoseno([0, 0], [1, 1]), 0);
      expect(similitudCoseno([1, 2], [1, 2, 3]), 0);
      expect(similitudCoseno([double.nan, 1], [1, 1]), 0);
    });

    test('la similitud con un sonido es la media de los ejemplos más parecidos', () {
      final consulta = normalizarEmbedding([1, 0]);
      final ejemplos = [
        normalizarEmbedding([1, 0]),
        normalizarEmbedding([0, 1]),
        normalizarEmbedding([1, 1])
      ];
      expect(similitudConSonido(consulta, ejemplos, cuantos: 2), closeTo((1 + math.sqrt1_2) / 2, 1e-6));
      expect(similitudConSonido(consulta, ejemplos, cuantos: 1), closeTo(1, 1e-6));
      expect(similitudConSonido(consulta, const [], cuantos: 2), 0);
    });
  });

  group('compararConSonidosPropios con vectores sintéticos', () {
    final mundo = MundoSintetico(2026);
    final perfilPerro = mundo.perfil();
    final perfilCarabo = mundo.perfil();
    final ejemplos = <EjemploSonidoPropio>[];
    var siguienteId = 1;
    for (var indice = 0; indice < 4; indice++) {
      ejemplos.add(ejemplo(siguienteId++, perro.id, mundo.muestraDe(perfilPerro)));
      ejemplos.add(ejemplo(siguienteId++, carabo.id, mundo.muestraDe(perfilCarabo)));
    }
    final preparados = prepararSonidosPropios([perro, carabo], ejemplos, versionModelo: 'europa-1');

    test('separa los dos sonidos: cada uno solo coincide con el suyo', () {
      for (var intento = 0; intento < 5; intento++) {
        final delPerro = compararConSonidosPropios(mundo.muestraDe(perfilPerro), preparados);
        expect(delPerro.sonidos.first.nombre, 'Mi perro');
        expect(delPerro.sonidos.first.coincide, isTrue);
        expect(delPerro.sonidos[1].coincide, isFalse);
        expect(delPerro.coincidencias.length, 1);

        final delCarabo = compararConSonidosPropios(mundo.muestraDe(perfilCarabo), preparados);
        expect(delCarabo.sonidos.map((sonido) => sonido.coincide), [true, false]);
        expect(delCarabo.sonidos.first.nombre, 'El cárabo del roble');
      }
    });

    test('un sonido que no es de ninguno no coincide', () {
      final ajeno = compararConSonidosPropios(mundo.muestraDe(mundo.perfil()), preparados);
      expect(ajeno.coincidencias, isEmpty);
      expect(ajeno.sonidos.first.similitud, lessThan(umbralSimilitudPorDefecto));
      expect(ajeno.similitudFondo, isNull);
    });

    test('el umbral controla la sensibilidad', () {
      final muestraPerro = mundo.muestraDe(perfilPerro);
      expect(
          compararConSonidosPropios(muestraPerro, preparados, umbralSimilitud: 0.999).coincidencias, isEmpty);
      expect(
          compararConSonidosPropios(muestraPerro, preparados, umbralSimilitud: -1).coincidencias.length, 2);
      expect(umbralPorSensibilidad[SensibilidadSonidosPropios.normal], 0.5);
    });

    test('el fondo descarta coincidencias que se le parecen más', () {
      final perfilFondo = mundo.perfil();
      final perroDebilEnElFondo = Float32List.fromList(
          [for (var i = 0; i < perfilFondo.length; i++) perfilFondo[i] + 0.5 * perfilPerro[i]]);
      final ejemplosFondo = [
        for (var i = 0; i < 3; i++) ejemplo(100 + i, fondo.id, mundo.muestraDe(perfilFondo))
      ];
      final conFondo = prepararSonidosPropios([perro, carabo, fondo], [...ejemplos, ...ejemplosFondo],
          versionModelo: 'europa-1');
      final resultado =
          compararConSonidosPropios(mundo.muestraDe(perroDebilEnElFondo), conFondo, umbralSimilitud: 0.1);
      final delPerro = resultado.sonidos.firstWhere((sonido) => sonido.nombre == 'Mi perro');
      expect(resultado.similitudFondo, isNotNull);
      expect(delPerro.coincide, isFalse);
      expect(delPerro.ganaElFondo, isTrue);
      expect(resultado.sonidos.map((sonido) => sonido.nombre), isNot(contains('Fondo')));
    });

    test('no usa sonidos con menos de 3 ejemplos ni ejemplos de otro modelo', () {
      final pocos = prepararSonidosPropios(
          [perro], ejemplos.where((e) => e.idSonido == perro.id).take(2).toList(),
          versionModelo: 'europa-1');
      expect(compararConSonidosPropios(mundo.muestraDe(perfilPerro), pocos).sonidos, isEmpty);
      final deOtroModelo = prepararSonidosPropios([
        perro
      ], [
        for (final e in ejemplos.where((e) => e.idSonido == perro.id))
          ejemplo(e.id, perro.id, e.embedding, version: 'otro')
      ], versionModelo: 'europa-1');
      expect(deOtroModelo.single.ejemplosNormalizados, isEmpty);
    });
  });

  test('nombres', () {
    expect(limpiarNombreSonido('  Mi   perro ')!, 'Mi perro');
    expect(limpiarNombreSonido('   '), isNull);
    expect(limpiarNombreSonido('x' * 100)!.length, longitudMaximaNombreSonido);
    expect(textoSimilitud(0.8712), '0,87');
  });

  test('embedding a bytes y vuelta', () {
    final original = Float32List.fromList([1, -0.5, 3.25, 0]);
    final bytes = embeddingABytes(original);
    expect(bytes.length, 16);
    expect(bytesAEmbedding(bytes), original);
  });
}
