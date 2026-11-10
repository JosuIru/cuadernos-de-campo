import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/barrido_rumbo.dart';
import 'package:naturaleza_flutter/sonido/triangulacion_rumbos.dart';

const double latitudBase = 43.0;
const double longitudBase = -2.0;

/// Toma a [esteMetros]/[norteMetros] del punto base.
TomaRumbo tomaEn(double esteMetros, double norteMetros, double rumbo,
    {double? precision, double incertidumbre = 10, bool orientativa = false}) {
  final posicion =
      ProyeccionLocal(latitudBase, longitudBase).aGeografica(PuntoLocal(esteMetros, norteMetros));
  return TomaRumbo(
    latitud: posicion.latitud,
    longitud: posicion.longitud,
    rumboGrados: rumbo,
    precisionMetros: precision,
    incertidumbreGrados: incertidumbre,
    orientativa: orientativa,
    momento: DateTime(2026, 11, 10, 8),
  );
}

PuntoLocal aLocal(({double latitud, double longitud}) posicion) =>
    ProyeccionLocal(latitudBase, longitudBase).aLocal(posicion.latitud, posicion.longitud);

void main() {
  group('ángulos', () {
    test('normaliza y cruza el norte', () {
      expect(normalizarRumbo(-10), closeTo(350, 1e-9));
      expect(normalizarRumbo(370), closeTo(10, 1e-9));
      expect(normalizarRumbo(360), closeTo(0, 1e-9));
      expect(diferenciaAngular(350, 10), closeTo(20, 1e-9));
      expect(diferenciaAngular(10, 350), closeTo(-20, 1e-9));
      expect(diferenciaAngular(0, 180), closeTo(180, 1e-9));
      expect(diferenciaAngular(90, 90), closeTo(0, 1e-9));
    });

    test('la media circular de 350° y 10° es 0°, no 180°', () {
      final media = mediaCircularGrados([350, 10, 355, 5]);
      expect(diferenciaAngular(0, media!).abs(), lessThan(1e-6));
      expect(mediaCircularGrados([0, 180]), isNull);
      expect(mediaCircularGrados([]), isNull);
    });

    test('ángulo de cruce entre rectas', () {
      expect(anguloCruceGrados(0, 90), closeTo(90, 1e-9));
      expect(anguloCruceGrados(0, 180), closeTo(0, 1e-9));
      expect(anguloCruceGrados(350, 10), closeTo(20, 1e-9));
      expect(anguloCruceGrados(10, 170), closeTo(20, 1e-9));
    });
  });

  group('proyección local', () {
    test('ida y vuelta, y un grado de latitud son ≈111 km', () {
      final proyeccion = ProyeccionLocal(latitudBase, longitudBase);
      final punto = proyeccion.aLocal(43.001, -1.999);
      final vuelta = proyeccion.aGeografica(punto);
      expect(vuelta.latitud, closeTo(43.001, 1e-9));
      expect(vuelta.longitud, closeTo(-1.999, 1e-9));
      expect(proyeccion.aLocal(44, -2).norte, closeTo(111195, 5));
      expect(distanciaMetros(43, -2, 43.001, -2), closeTo(111.2, 0.5));
    });
  });

  group('intersección de rectas', () {
    test('dos rumbos que se cruzan delante', () {
      final cruce = interseccionRectas(const PuntoLocal(0, 0), 45, const PuntoLocal(100, 0), 315)!;
      expect(cruce.punto.este, closeTo(50, 1e-6));
      expect(cruce.punto.norte, closeTo(50, 1e-6));
      expect(cruce.avanceA, greaterThan(0));
      expect(cruce.avanceB, greaterThan(0));
    });

    test('paralelas: null', () {
      expect(interseccionRectas(const PuntoLocal(0, 0), 0, const PuntoLocal(100, 0), 0), isNull);
      expect(interseccionRectas(const PuntoLocal(0, 0), 0, const PuntoLocal(100, 0), 180), isNull);
    });

    test('cruce a la espalda: avance negativo', () {
      final cruce = interseccionRectas(const PuntoLocal(0, 0), 315, const PuntoLocal(100, 0), 45)!;
      expect(cruce.avanceA, lessThan(0));
    });
  });

  group('polígonos', () {
    test('cuña convexa, antihoraria y que contiene su rumbo', () {
      final cuna = cunaDeToma(
          origen: const PuntoLocal(0, 0), rumboGrados: 0, semiaperturaGrados: 10, alcanceMetros: 1000);
      expect(areaConSigno(cuna), greaterThan(0));
      final punta = recortarConPoligonoConvexo([
        const PuntoLocal(-1, 499),
        const PuntoLocal(1, 499),
        const PuntoLocal(1, 501),
        const PuntoLocal(-1, 501),
      ], cuna);
      expect(areaConSigno(punta).abs(), closeTo(4, 1e-6));
    });

    test('una cuña que cruza el norte (355° ± 10°) cubre el norte y no el sur', () {
      final cuna = cunaDeToma(
          origen: const PuntoLocal(0, 0), rumboGrados: 355, semiaperturaGrados: 10, alcanceMetros: 1000);
      List<PuntoLocal> cuadradito(double este, double norte) => [
            PuntoLocal(este - 1, norte - 1),
            PuntoLocal(este + 1, norte - 1),
            PuntoLocal(este + 1, norte + 1),
            PuntoLocal(este - 1, norte + 1),
          ];
      expect(recortarConPoligonoConvexo(cuadradito(0, 500), cuna), isNotEmpty);
      // 3° al este del norte, dentro de 345°…5°.
      expect(
          recortarConPoligonoConvexo(cuadradito(500 * math.sin(3 * math.pi / 180), 500), cuna), isNotEmpty);
      // 10° al este: fuera.
      expect(recortarConPoligonoConvexo(cuadradito(500 * math.sin(10 * math.pi / 180), 500), cuna), isEmpty);
      expect(recortarConPoligonoConvexo(cuadradito(0, -500), cuna), isEmpty);
    });

    test('recorte de dos cuadrados y centroide', () {
      final cuadradoA = [
        const PuntoLocal(0, 0),
        const PuntoLocal(2, 0),
        const PuntoLocal(2, 2),
        const PuntoLocal(0, 2),
      ];
      // El segundo, en sentido horario: también vale.
      final cuadradoB = [
        const PuntoLocal(1, 1),
        const PuntoLocal(1, 3),
        const PuntoLocal(3, 3),
        const PuntoLocal(3, 1),
      ];
      final interseccion = recortarConPoligonoConvexo(cuadradoA, cuadradoB);
      expect(areaConSigno(interseccion).abs(), closeTo(1, 1e-9));
      final centro = centroidePoligono(interseccion)!;
      expect(centro.este, closeTo(1.5, 1e-9));
      expect(centro.norte, closeTo(1.5, 1e-9));
    });

    test('retroceso por el error del GPS', () {
      expect(retrocesoPorPrecision(null, 10, 1500), 0);
      expect(retrocesoPorPrecision(5, 30, 1500), closeTo(10, 1e-9));
      // Con un error enorme se limita a la mitad del alcance.
      expect(retrocesoPorPrecision(1000, 10, 1500), 750);
    });
  });

  group('estimarZona', () {
    test('dos tomas que se cruzan: el centro cae donde está el animal', () {
      // Animal en (50, 300): desde (0, 0) y (200, 0).
      double rumboHacia(double este, double norte, double esteAnimal, double norteAnimal) =>
          normalizarRumbo(math.atan2(esteAnimal - este, norteAnimal - norte) * 180 / math.pi);
      final tomas = [
        tomaEn(0, 0, rumboHacia(0, 0, 50, 300), incertidumbre: 5),
        tomaEn(200, 0, rumboHacia(200, 0, 50, 300), incertidumbre: 5),
      ];
      final zona = estimarZona(tomas);
      expect(zona.hayZona, isTrue);
      expect(zona.avisos, isEmpty);
      final centro = aLocal(zona.centro!);
      expect(centro.este, closeTo(50, 15));
      expect(centro.norte, closeTo(300, 40));
      expect(zona.areaMetrosCuadrados, greaterThan(100));
      expect(zona.areaMetrosCuadrados, lessThan(20000));
      expect(zona.distanciaMinimaMetros, closeTo(300, 50));
      final json = zona.aJson(tomas);
      expect((json['contorno'] as List).length, zona.contorno.length);
      expect((json['tomas'] as List).length, 2);
      expect(TomaRumbo.desdeJson((json['tomas'] as List).first)!.rumboGrados,
          closeTo(tomas.first.rumboGrados, 0.05));
    });

    test('rumbos a ambos lados del norte (10° y 350°)', () {
      final zona = estimarZona([tomaEn(0, 0, 10, incertidumbre: 3), tomaEn(100, 0, 350, incertidumbre: 3)]);
      expect(zona.hayZona, isTrue);
      final centro = aLocal(zona.centro!);
      // Se cruzan en (50, 50 / tan 10°) ≈ (50, 284).
      expect(centro.este, closeTo(50, 5));
      expect(centro.norte, closeTo(284, 120));
      expect(zona.avisos, isNot(contains(AvisoTriangulacion.rumbosNoSeCruzanDelante)));
    });

    test('una sola toma: pide otra', () {
      final zona = estimarZona([tomaEn(0, 0, 0)]);
      expect(zona.hayZona, isFalse);
      expect(zona.avisos, contains(AvisoTriangulacion.pocasTomas));
    });

    test('tomas demasiado juntas', () {
      final zona = estimarZona([tomaEn(0, 0, 45), tomaEn(5, 0, 315)]);
      expect(zona.avisos, contains(AvisoTriangulacion.tomasDemasiadoJuntas));
      // Tampoco valen si están más cerca que el error de sus GPS.
      final conGpsMalo = estimarZona([tomaEn(0, 0, 45, precision: 30), tomaEn(40, 0, 315, precision: 30)]);
      expect(conGpsMalo.avisos, contains(AvisoTriangulacion.tomasDemasiadoJuntas));
    });

    test('rumbos casi paralelos', () {
      final zona = estimarZona([tomaEn(0, 0, 0), tomaEn(100, 0, 5)]);
      expect(zona.avisos, contains(AvisoTriangulacion.rumbosCasiParalelos));
      final opuestos = estimarZona([tomaEn(0, 0, 90), tomaEn(0, 100, 268)]);
      expect(opuestos.avisos, contains(AvisoTriangulacion.rumbosCasiParalelos));
    });

    test('rumbos que se separan: no se cruzan delante ni hay zona', () {
      final zona = estimarZona([tomaEn(0, 0, 315), tomaEn(100, 0, 45)]);
      expect(zona.avisos, contains(AvisoTriangulacion.rumbosNoSeCruzanDelante));
      expect(zona.avisos, contains(AvisoTriangulacion.sinInterseccion));
      expect(zona.hayZona, isFalse);
    });

    test('tres tomas coherentes afinan; una que no cuadra deja sin zona', () {
      final dosTomas = estimarZona([tomaEn(0, 0, 45), tomaEn(200, 0, 315)]);
      final tresTomas =
          estimarZona([tomaEn(0, 0, 45), tomaEn(200, 0, 315), tomaEn(100, 300, 180, incertidumbre: 3)]);
      expect(tresTomas.hayZona, isTrue);
      expect(tresTomas.areaMetrosCuadrados, lessThan(dosTomas.areaMetrosCuadrados));
      final centro = aLocal(tresTomas.centro!);
      expect(centro.este, closeTo(100, 15));
      expect(centro.norte, closeTo(100, 15));
      final incoherente = estimarZona([tomaEn(0, 0, 45), tomaEn(200, 0, 315), tomaEn(100, 300, 90)]);
      expect(incoherente.avisos, contains(AvisoTriangulacion.sinInterseccion));
    });

    test('el error del GPS agranda la zona', () {
      final sinError = estimarZona([tomaEn(0, 0, 45), tomaEn(200, 0, 315)]);
      final conError = estimarZona([tomaEn(0, 0, 45, precision: 20), tomaEn(200, 0, 315, precision: 20)]);
      expect(conError.areaMetrosCuadrados, greaterThan(sinError.areaMetrosCuadrados));
    });

    test('una toma del barrido marca la zona como orientativa', () {
      final zona = estimarZona([tomaEn(0, 0, 45), tomaEn(200, 0, 315, incertidumbre: 20, orientativa: true)]);
      expect(zona.avisos, contains(AvisoTriangulacion.hayTomasOrientativas));
      expect(zona.hayZona, isTrue);
    });
  });

  group('barrido', () {
    List<MuestraBarrido> vuelta(double rumboFuente, {double desdeGrados = 0, double hastaGrados = 360}) => [
          for (var rumbo = desdeGrados; rumbo < hastaGrados; rumbo += 2)
            MuestraBarrido(
                normalizarRumbo(rumbo), -50 + 4 * (1 + math.cos((rumbo - rumboFuente) * math.pi / 180))),
        ];

    test('propone el rumbo de más nivel', () {
      final resultado = analizarBarrido(vuelta(120));
      expect(resultado.hayMaximoClaro, isTrue);
      expect(diferenciaAngular(120, resultado.rumboMaximoGrados!).abs(), lessThan(6));
      expect(resultado.coberturaGrados, closeTo(360, 1e-9));
    });

    test('máximo junto al norte (355°)', () {
      final resultado = analizarBarrido(vuelta(355));
      expect(diferenciaAngular(355, resultado.rumboMaximoGrados!).abs(), lessThan(6));
    });

    test('nivel plano: sin máximo claro', () {
      final resultado =
          analizarBarrido([for (var rumbo = 0.0; rumbo < 360; rumbo += 2) MuestraBarrido(rumbo, -50)]);
      expect(resultado.hayMaximoClaro, isFalse);
      expect(resultado.contrasteDecibelios, closeTo(0, 1e-6));
    });

    test('media vuelta corta no basta', () {
      final resultado = analizarBarrido(vuelta(45, desdeGrados: 0, hastaGrados: 90));
      expect(resultado.coberturaSuficiente, isFalse);
      expect(resultado.hayMaximoClaro, isFalse);
    });

    test('sin muestras', () {
      final resultado = analizarBarrido(const []);
      expect(resultado.coberturaGrados, 0);
      expect(resultado.rumboMaximoGrados, isNull);
    });
  });
}
