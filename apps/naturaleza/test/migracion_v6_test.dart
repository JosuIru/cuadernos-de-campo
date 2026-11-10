import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:naturaleza_flutter/datos/base_datos.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/sonido/registro_sesion_sonora.dart';

/// v6 añade las sesiones largas de escucha (recorrido y coro del amanecer)
/// con sus detecciones, y la nota de voz del hallazgo.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('la versión declarada es la 6', () {
    expect(versionEsquemaNaturaleza, 6);
  });

  test('migración v5 → v6 conserva los hallazgos y añade sesiones y nota de voz', () async {
    final rutaTemporal = '${Directory.systemTemp.path}/test_migracion_v6.db';
    await databaseFactory.deleteDatabase(rutaTemporal);

    var baseDatos = await openDatabase(rutaTemporal, version: 5, onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: 5);
    });
    // Un hallazgo sin nota (toMap no incluye la columna nueva).
    final idHallazgo = await baseDatos.insert(
      'hallazgos',
      Hallazgo(
        fechaMs: 1700000000000,
        latitud: 43.3,
        longitud: -2.0,
        especie: 'Strix aluco',
        rutaAudio: '/datos/audios/sonido_1.wav',
      ).toMap()
        ..remove('id'),
    );
    await baseDatos.insert('sonidos_propios', {'nombre': 'Fondo', 'es_fondo': 1, 'creado_ms': 1});
    await baseDatos.close();

    baseDatos = await openDatabase(rutaTemporal, version: 6, onUpgrade: (db, desde, hasta) async {
      await aplicarMigraciones(db, desde: desde, hasta: hasta);
    });
    final hallazgo = Hallazgo.fromMap(
        (await baseDatos.query('hallazgos', where: 'id = ?', whereArgs: [idHallazgo])).single);
    expect(hallazgo.especie, 'Strix aluco');
    expect(hallazgo.rutaAudio, '/datos/audios/sonido_1.wav');
    expect(hallazgo.rutaNotaVoz, isNull);
    expect((await baseDatos.query('sonidos_propios')).single['nombre'], 'Fondo');

    await baseDatos.update('hallazgos', {'ruta_nota_voz': '/datos/notas_voz/nota_1.m4a'},
        where: 'id = ?', whereArgs: [idHallazgo]);
    final conNota = Hallazgo.fromMap((await baseDatos.query('hallazgos')).single);
    expect(conNota.rutaNotaVoz, '/datos/notas_voz/nota_1.m4a');
    expect(conNota.toMap()['ruta_nota_voz'], '/datos/notas_voz/nota_1.m4a');

    final sesion = SesionSonora(
      tipo: TipoSesionSonora.recorrido,
      inicioMs: 1700000000000,
      versionModelo: 'europa-1',
      traza: const [PuntoTrazaSonora(momentoMs: 1700000000000, latitud: 43.3, longitud: -2)],
    );
    final idSesion = await baseDatos.insert('sesiones_sonoras', sesion.aMapa()..remove('id'));
    await baseDatos.insert(
      'detecciones_sonoras',
      DeteccionSonora(
        sesionId: idSesion,
        momentoMs: 1700000005000,
        etiqueta: 'Strix aluco',
        nombreComun: 'Cárabo',
        categoria: 'ave',
        puntuacion: 12,
        puntuacionModelo: 12,
        latitud: 43.3,
        longitud: -2,
        indicePuntoTraza: 0,
      ).aMapa()
        ..remove('id'),
    );
    final leida = SesionSonora.desdeMapa((await baseDatos.query('sesiones_sonoras')).single);
    expect(leida.traza.single.latitud, 43.3);
    expect(leida.terminada, isFalse);
    final deteccion = DeteccionSonora.desdeMapa((await baseDatos.query('detecciones_sonoras')).single);
    expect(deteccion.sesionId, idSesion);
    expect(deteccion.nombreComun, 'Cárabo');

    // Repetir la migración no rompe nada.
    await aplicarMigraciones(baseDatos, desde: 5, hasta: 6);
    await baseDatos.close();
    await databaseFactory.deleteDatabase(rutaTemporal);
  });

  test('una base de datos nueva v6 tiene todas las tablas', () async {
    final baseDatos = await openDatabase(inMemoryDatabasePath, version: 6, onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: version);
    });
    final tablas = (await baseDatos.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((fila) => fila['name'])
        .toSet();
    expect(tablas, containsAll(['hallazgos', 'sonidos_propios', 'sesiones_sonoras', 'detecciones_sonoras']));
    final columnas = await baseDatos.rawQuery('PRAGMA table_info(hallazgos)');
    expect(columnas.map((columna) => columna['name']), containsAll(['ruta_audio', 'ruta_nota_voz']));
    await baseDatos.close();
  });
}
