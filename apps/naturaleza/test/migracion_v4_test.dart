import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:naturaleza_flutter/datos/base_datos.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';

/// v4 añade `ruta_audio` (clip de «¿Quién canta?») a los hallazgos.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migración v3 → v4 conserva los hallazgos y deja la columna de audio vacía', () async {
    final rutaTemporal = '${Directory.systemTemp.path}/test_migracion_v4.db';
    await databaseFactory.deleteDatabase(rutaTemporal);

    var baseDatos = await openDatabase(rutaTemporal, version: 3, onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: 3);
    });
    final idViejo = await baseDatos.insert(
      'hallazgos',
      Hallazgo(fechaMs: 1700000000000, latitud: 43.3, longitud: -2.0, especie: 'Turdus merula')
          .toMap()
        ..remove('id'),
    );
    await baseDatos.close();

    baseDatos = await openDatabase(rutaTemporal, version: 4, onUpgrade: (db, desde, hasta) async {
      await aplicarMigraciones(db, desde: desde, hasta: hasta);
    });
    final filaVieja =
        (await baseDatos.query('hallazgos', where: 'id = ?', whereArgs: [idViejo])).single;
    final hallazgoViejo = Hallazgo.fromMap(filaVieja);
    expect(hallazgoViejo.especie, 'Turdus merula');
    expect(hallazgoViejo.rutaAudio, isNull);

    final hallazgoConAudio = Hallazgo(
      fechaMs: 1700000100000,
      latitud: 43.3,
      longitud: -2.0,
      categoria: 'ave',
      especie: 'Erithacus rubecula',
      tipoEvidencia: TipoEvidencia.sonido,
      rutaAudio: '/datos/audios/sonido_1.wav',
      atributos: const {
        'identificacion_sonido': {'modelo': 'europa-1', 'puntuacion': 11.2},
      },
    );
    final idNuevo = await baseDatos.insert('hallazgos', hallazgoConAudio.toMap()..remove('id'));
    final leido = Hallazgo.fromMap(
        (await baseDatos.query('hallazgos', where: 'id = ?', whereArgs: [idNuevo])).single);
    expect(leido.rutaAudio, '/datos/audios/sonido_1.wav');
    expect(leido.tipoEvidencia, TipoEvidencia.sonido);
    expect((leido.atributos['identificacion_sonido'] as Map)['modelo'], 'europa-1');
    expect(leido.copyWith(quitarAudio: true).rutaAudio, isNull);
    expect(leido.copyWith(notas: 'x').rutaAudio, '/datos/audios/sonido_1.wav');
    await baseDatos.close();
    await databaseFactory.deleteDatabase(rutaTemporal);
  });

  test('una base de datos nueva v4 ya tiene la columna de audio', () async {
    final baseDatos = await openDatabase(inMemoryDatabasePath, version: 4,
        onCreate: (db, version) async {
      await crearEsquemaInicial(db);
      await aplicarMigraciones(db, desde: 1, hasta: version);
    });
    final columnas = await baseDatos.rawQuery('PRAGMA table_info(hallazgos)');
    expect(columnas.map((columna) => columna['name']), contains('ruta_audio'));
    await baseDatos.close();
  });
}
