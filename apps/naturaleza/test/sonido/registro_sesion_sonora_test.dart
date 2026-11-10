import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/clasificacion_sonido.dart';
import 'package:naturaleza_flutter/sonido/especies_vigiladas.dart';
import 'package:naturaleza_flutter/sonido/manifiesto_modelo_fauna.dart';
import 'package:naturaleza_flutter/sonido/registro_sesion_sonora.dart';

DeteccionSonora _deteccion(String etiqueta, DateTime momento, double puntuacion,
        {double? latitud, double? longitud, String? rutaClip}) =>
    DeteccionSonora(
      momentoMs: momento.millisecondsSinceEpoch,
      etiqueta: etiqueta,
      nombreComun: etiqueta == 'Erithacus rubecula' ? 'Petirrojo' : '',
      categoria: 'ave',
      puntuacion: puntuacion,
      puntuacionModelo: puntuacion,
      latitud: latitud,
      longitud: longitud,
      rutaClip: rutaClip,
    );

void main() {
  final inicio = DateTime(2026, 5, 1, 6, 7);

  group('traza', () {
    final traza = [
      for (var indice = 0; indice < 5; indice++)
        PuntoTrazaSonora(
          momentoMs: inicio.add(Duration(minutes: indice)).millisecondsSinceEpoch,
          latitud: 43 + indice * 0.0001,
          longitud: -2,
          precisionMetros: 5,
        ),
    ];

    test('cada detección va al último punto tomado antes', () {
      int ms(int segundos) => inicio.add(Duration(seconds: segundos)).millisecondsSinceEpoch;
      expect(indicePuntoTrazaPara(traza, ms(0)), 0);
      expect(indicePuntoTrazaPara(traza, ms(59)), 0);
      expect(indicePuntoTrazaPara(traza, ms(60)), 1);
      expect(indicePuntoTrazaPara(traza, ms(150)), 2);
      // Quieto mucho rato tras el último punto: sigue en él.
      expect(indicePuntoTrazaPara(traza, ms(3600)), 4);
    });

    test('antes del primer punto, solo si está cerca en el tiempo', () {
      expect(indicePuntoTrazaPara(traza, inicio.subtract(const Duration(seconds: 90)).millisecondsSinceEpoch), 0);
      expect(indicePuntoTrazaPara(traza, inicio.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch), isNull);
      expect(indicePuntoTrazaPara(const [], inicio.millisecondsSinceEpoch), isNull);
    });

    test('ida y vuelta por JSON y distancia', () {
      final vuelta = trazaDesdeJson(trazaAJson(traza));
      expect(vuelta.length, 5);
      expect(vuelta[3].latitud, closeTo(43.0003, 1e-9));
      expect(vuelta[3].precisionMetros, 5);
      // 4 tramos de 0,0001° de latitud ≈ 11,1 m cada uno.
      expect(distanciaTrazaMetros(traza), closeTo(44.5, 0.5));
      expect(trazaDesdeJson('no es json'), isEmpty);
      expect(trazaDesdeJson(null), isEmpty);
    });
  });

  group('agrupación por especie', () {
    test('cuenta, primera, última, mejor y clip', () {
      final detecciones = [
        _deteccion('Turdus merula', inicio.add(const Duration(minutes: 1)), 9),
        _deteccion('Erithacus rubecula', inicio, 8, latitud: 43, longitud: -2),
        _deteccion('Erithacus rubecula', inicio.add(const Duration(minutes: 3)), 12,
            rutaClip: '/a/clip.wav'),
        _deteccion('Erithacus rubecula', inicio.add(const Duration(minutes: 5)), 10, latitud: 43.1, longitud: -2),
      ];
      final grupos = agruparDeteccionesPorEspecie(detecciones);
      expect(grupos.map((grupo) => grupo.etiqueta), ['Erithacus rubecula', 'Turdus merula']);
      final petirrojo = grupos.first;
      expect(petirrojo.numeroDetecciones, 3);
      expect(petirrojo.nombreComun, 'Petirrojo');
      expect(petirrojo.primera.momentoMs, inicio.millisecondsSinceEpoch);
      expect(petirrojo.ultima.puntuacion, 10);
      expect(petirrojo.mejor.puntuacion, 12);
      expect(petirrojo.nivelMejor, NivelConfianzaSonido.probable);
      expect(petirrojo.rutaClip, '/a/clip.wav');
      // La mejor no tiene posición: para el hallazgo, la mejor con posición.
      expect(petirrojo.mejorConPosicion!.latitud, 43.1);
      expect(grupos.last.mejorConPosicion, isNull);
    });
  });

  group('franjas de 15 minutos', () {
    test('alineadas al reloj, con las vacías', () {
      final fin = DateTime(2026, 5, 1, 7, 2);
      final detecciones = [
        _deteccion('A', DateTime(2026, 5, 1, 6, 8), 9),
        _deteccion('A', DateTime(2026, 5, 1, 6, 14, 59), 9),
        _deteccion('B', DateTime(2026, 5, 1, 6, 15), 9),
        _deteccion('A', DateTime(2026, 5, 1, 7, 1), 9),
        // Fuera de la sesión: no cuenta.
        _deteccion('C', DateTime(2026, 5, 1, 7, 30), 9),
      ];
      final franjas = franjasDeActividad(detecciones, inicio: inicio, fin: fin);
      expect(franjas.map((franja) => franja.inicio.minute), [0, 15, 30, 45, 0]);
      expect(franjas.first.inicio, DateTime(2026, 5, 1, 6, 0));
      expect(franjas[0].deteccionesPorEspecie, {'A': 2});
      expect(franjas[1].deteccionesPorEspecie, {'B': 1});
      expect(franjas[2].numeroDetecciones, 0);
      expect(franjas[4].numeroEspecies, 1);
      expect(franjasDeActividad(detecciones, inicio: fin, fin: inicio), isEmpty);
    });

    test('especies de la franja de la más oída a la menos', () {
      final franja = franjasDeActividad([
        _deteccion('B', DateTime(2026, 5, 1, 6, 8), 9),
        _deteccion('A', DateTime(2026, 5, 1, 6, 9), 9),
        _deteccion('A', DateTime(2026, 5, 1, 6, 10), 9),
      ], inicio: inicio, fin: DateTime(2026, 5, 1, 6, 12))
          .single;
      expect(franja.especiesPorDetecciones, ['A', 'B']);
    });
  });

  group('hora de fin del coro', () {
    test('por duración o por hora del reloj', () {
      expect(finDelCoro(inicio: inicio, duracion: const Duration(minutes: 90)), DateTime(2026, 5, 1, 7, 37));
      expect(finDelCoro(inicio: inicio, horaFin: 8, minutoFin: 30), DateTime(2026, 5, 1, 8, 30));
      // Si la hora ya ha pasado hoy, es mañana.
      expect(finDelCoro(inicio: inicio, horaFin: 5, minutoFin: 0), DateTime(2026, 5, 2, 5, 0));
      expect(proximaHoraDelReloj(inicio, 6, 7), DateTime(2026, 5, 2, 6, 7));
      expect(() => finDelCoro(inicio: inicio), throwsArgumentError);
    });
  });

  group('CSV', () {
    test('cabecera, orden por hora, comillas y clip', () {
      final sesion = SesionSonora(
        id: 7,
        tipo: TipoSesionSonora.coro,
        inicioMs: inicio.millisecondsSinceEpoch,
        versionModelo: 'europa-1',
      );
      final csv = csvDeteccionesSesion(sesion, [
        DeteccionSonora(
          momentoMs: DateTime(2026, 5, 1, 6, 30).millisecondsSinceEpoch,
          etiqueta: 'Turdus merula',
          nombreComun: 'Mirlo, común',
          categoria: 'ave',
          puntuacion: 11.26,
          puntuacionModelo: 12,
          rutaClip: '/datos/audios/sesion_7_turdus.wav',
        ),
        DeteccionSonora(
          momentoMs: DateTime(2026, 5, 1, 6, 10).millisecondsSinceEpoch,
          etiqueta: 'Erithacus rubecula',
          nombreComun: 'Petirrojo "europeo"',
          categoria: 'ave',
          puntuacion: 8,
          puntuacionModelo: 8,
          latitud: 43.123456789,
          longitud: -2.5,
        ),
      ], nombreFicheroClip: (ruta) => ruta.split('/').last);
      final lineas = csv.split('\r\n');
      expect(lineas.first, cabeceraCsvDetecciones);
      expect(lineas[1],
          '7,coro,2026-05-01T06:10:00,Erithacus rubecula,"Petirrojo ""europeo""",ave,8.0,8.0,posible,43.123457,-2.500000,');
      expect(lineas[2],
          '7,coro,2026-05-01T06:30:00,Turdus merula,"Mirlo, común",ave,11.3,12.0,probable,,,sesion_7_turdus.wav');
      expect(lineas.last, '');
    });

    test('sesión y detección: ida y vuelta por la BD', () {
      final sesion = SesionSonora(
        tipo: TipoSesionSonora.recorrido,
        inicioMs: 1,
        finMs: 2,
        versionModelo: 'v',
        traza: const [PuntoTrazaSonora(momentoMs: 1, latitud: 43, longitud: -2)],
        conFiltroDeZona: true,
      );
      final vuelta = SesionSonora.desdeMapa(sesion.aMapa());
      expect(vuelta.tipo, TipoSesionSonora.recorrido);
      expect(vuelta.traza.single.latitud, 43);
      expect(vuelta.conFiltroDeZona, isTrue);
      expect(vuelta.terminada, isTrue);
      final deteccion = _deteccion('A', inicio, 10.5, latitud: 1, longitud: 2);
      final mapa = deteccion.aMapa();
      expect(mapa['nivel'], 'probable');
      expect(DeteccionSonora.desdeMapa(mapa).puntuacion, 10.5);
    });
  });

  group('especies vigiladas', () {
    const clases = [
      ClaseSonido(etiqueta: 'Human_voice', tipo: TipoClaseSonido.sonido, esVozHumana: true),
      ClaseSonido(
          etiqueta: 'Erithacus rubecula',
          tipo: TipoClaseSonido.especie,
          grupo: GrupoEspecieSonido.ave,
          nombres: {'es': 'Petirrojo europeo', 'eu': 'Txantxangorria'}),
      ClaseSonido(
          etiqueta: 'Bufo bufo',
          tipo: TipoClaseSonido.especie,
          grupo: GrupoEspecieSonido.anfibio,
          nombres: {'es': 'Sapo común'}),
      ClaseSonido(etiqueta: 'Dog', tipo: TipoClaseSonido.sonido),
    ];

    test('avisa solo de las vigiladas en nivel probable y no repite enseguida', () {
      final vigilante = VigilanteEspecies(['Erithacus rubecula']);
      final momento = DateTime(2026, 5, 1, 6);
      const probable = ClaseClasificada(indiceClase: 1, puntuacion: 11, puntuacionModelo: 11);
      const posible = ClaseClasificada(indiceClase: 1, puntuacion: 8, puntuacionModelo: 8);
      const sapo = ClaseClasificada(indiceClase: 2, puntuacion: 14, puntuacionModelo: 14);
      expect(vigilante.avisosPara([posible, sapo], clases, momento), isEmpty);
      expect(vigilante.avisosPara([probable, sapo], clases, momento).single.indiceClase, 1);
      expect(vigilante.avisosPara([probable], clases, momento.add(const Duration(minutes: 4))), isEmpty);
      expect(vigilante.avisosPara([probable], clases, momento.add(const Duration(minutes: 5))), hasLength(1));
      vigilante.reiniciar();
      expect(vigilante.avisosPara([probable], clases, momento.add(const Duration(minutes: 6))), hasLength(1));
      expect(VigilanteEspecies(const []).avisosPara([probable], clases, momento), isEmpty);
    });

    test('se eligen entre las especies del manifiesto, buscando sin tildes', () {
      expect(clasesVigilables(clases, '', idioma: 'es').map((clase) => clase.etiqueta),
          ['Erithacus rubecula', 'Bufo bufo']);
      expect(clasesVigilables(clases, 'SAPO', idioma: 'es').single.etiqueta, 'Bufo bufo');
      expect(clasesVigilables(clases, 'txantxan', idioma: 'es').single.etiqueta, 'Erithacus rubecula');
      expect(clasesVigilables(clases, 'eríthacus', idioma: 'es').single.etiqueta, 'Erithacus rubecula');
      expect(clasesVigilables(clases, 'dog', idioma: 'es'), isEmpty);
      expect(normalizarParaBuscar('  Ñandú_Común '), 'nandu comun');
    });
  });
}
