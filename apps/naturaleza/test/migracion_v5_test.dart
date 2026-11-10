import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:naturaleza_flutter/datos/base_datos.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/sonido/sonidos_propios.dart';

/// v5 añade las tablas de «Tus sonidos» (sonidos propios y sus embeddings).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('la versión declarada es la 5', () {
    expect(versionEsquemaNaturaleza, 5);
  });

  test('migración v4 → v5 conserva los hallazgos y crea las tablas de sonidos', () async {
    final rutaTemporal = '${Directory.systemTemp.path}/test_migracion_v5.db';
    await databaseFactory.deleteDatabase(rutaTemporal);

    var baseDatos = await openDatabase(rutaTemporal, version: 4, onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: 4);
    });
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
    await baseDatos.close();

    baseDatos = await openDatabase(rutaTemporal, version: 5, onUpgrade: (db, desde, hasta) async {
      await aplicarMigraciones(db, desde: desde, hasta: hasta);
    });
    final hallazgo = Hallazgo.fromMap(
        (await baseDatos.query('hallazgos', where: 'id = ?', whereArgs: [idHallazgo])).single);
    expect(hallazgo.especie, 'Strix aluco');
    expect(hallazgo.rutaAudio, '/datos/audios/sonido_1.wav');

    final idSonido = await baseDatos.insert('sonidos_propios', {
      'nombre': 'El cárabo del roble',
      'es_fondo': 0,
      'creado_ms': 1700000000000,
    });
    final embedding =
        Float32List.fromList(List.generate(dimensionesEmbeddingPerch, (indice) => indice / 1000));
    await baseDatos.insert('ejemplos_sonido_propio', {
      'sonido_id': idSonido,
      'creado_ms': 1700000000000,
      'version_modelo': 'europa-1',
      'embedding': embeddingABytes(embedding),
    });
    final fila = (await baseDatos.query('ejemplos_sonido_propio')).single;
    expect(bytesAEmbedding(fila['embedding'] as Uint8List), embedding);
    // Repetir la migración no rompe nada (IF NOT EXISTS).
    await aplicarMigraciones(baseDatos, desde: 4, hasta: 5);
    await baseDatos.close();
    await databaseFactory.deleteDatabase(rutaTemporal);
  });

  test('una base de datos nueva v5 tiene todas las tablas', () async {
    final baseDatos = await openDatabase(inMemoryDatabasePath, version: 5, onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: version);
    });
    final tablas = (await baseDatos.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((fila) => fila['name'])
        .toSet();
    expect(tablas, containsAll(['hallazgos', 'salidas', 'sonidos_propios', 'ejemplos_sonido_propio']));
    final columnas = await baseDatos.rawQuery('PRAGMA table_info(hallazgos)');
    expect(columnas.map((columna) => columna['name']), contains('ruta_audio'));
    await baseDatos.close();
  });
}
