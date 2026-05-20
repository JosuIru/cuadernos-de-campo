import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:naturaleza_flutter/datos/base_datos.dart';
import 'package:naturaleza_flutter/modelos/anotacion_diferida.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/modelos/salida.dart';

/// Una sesión de pruebas comparte ffi factory. Aquí no usamos
/// [BaseDatosNaturaleza] (singleton atado a path_provider), sino
/// `openDatabase` directo en memoria, exponiendo las funciones
/// `crearEsquemaInicial` y `aplicarMigraciones` del paquete.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('migración v2 → v3', () {
    test('preserva hallazgos antiguos y añade columnas con defaults',
        () async {
      // El upgrade onUpgrade sólo se dispara si la BD persiste entre
      // openDatabase calls — un BD en memoria se crea limpia cada vez.
      // Usamos por tanto un fichero temporal.
      final rutaTemp = '${Directory.systemTemp.path}/test_migracion_v3.db';
      try {
        // Limpia restos previos.
        await databaseFactory.deleteDatabase(rutaTemp);
      } catch (_) {}

      var dbPersistente = await openDatabase(rutaTemp, version: 2,
          onCreate: (db, version) async {
        await crearEsquemaInicial(db);
        await aplicarMigraciones(db, desde: 1, hasta: 2);
      });
      final idViejoEnDisco = await dbPersistente.insert('hallazgos', {
        'fecha_ms': 1700000000000,
        'latitud': 43.5,
        'longitud': -2.1,
        'categoria': 'animal',
        'especie': 'Saxicola rubicola',
        'nombre_comun': 'tarabilla común',
        'taxonomia': '',
        'habitat': '',
        'notas': '',
      });
      await dbPersistente.close();

      // Reabrir con version 3 → onUpgrade.
      dbPersistente = await openDatabase(rutaTemp, version: 3,
          onUpgrade: (db, desde, hasta) async {
        await aplicarMigraciones(db, desde: desde, hasta: hasta);
      });

      final filas = await dbPersistente
          .query('hallazgos', where: 'id = ?', whereArgs: [idViejoEnDisco]);
      expect(filas.length, 1);
      final hallazgoTrasMigrar = Hallazgo.fromMap(filas.first);
      expect(hallazgoTrasMigrar.especie, 'Saxicola rubicola');
      expect(hallazgoTrasMigrar.salidaId, isNull,
          reason: 'salida_id debe ser NULL en hallazgos pre-v3');
      expect(hallazgoTrasMigrar.tipoEvidencia, TipoEvidencia.avistamiento,
          reason: 'tipo_evidencia debe defaulteear a avistamiento');
      expect(hallazgoTrasMigrar.identificacionValidada,
          EstadoIdentificacion.sinRevisar);
      expect(hallazgoTrasMigrar.hipotesis, '');
      expect(hallazgoTrasMigrar.confianzaIdentificacion, isNull);

      await dbPersistente.close();
    });

    test('CRUD de Salida y borrado desasocia hallazgos', () async {
      final rutaTemp = '${Directory.systemTemp.path}/test_salida_crud.db';
      try {
        await databaseFactory.deleteDatabase(rutaTemp);
      } catch (_) {}
      final db = await openDatabase(rutaTemp, version: 3,
          onCreate: (db, version) async {
        await crearEsquemaInicial(db);
        await aplicarMigraciones(db, desde: 1, hasta: 3);
      });

      // Crea salida nueva.
      final salida = Salida(
        fechaInicioMs: 1750000000000,
        titulo: 'Encinares del Pirulén',
        zona: 'Sierra de la Demanda',
      );
      final idSalida =
          await db.insert('salidas', salida.toMap()..remove('id'));
      expect(idSalida, greaterThan(0));

      // Inserta dos hallazgos colgados de la salida.
      final hallazgoConSalida = Hallazgo(
        fechaMs: 1750000100000,
        latitud: 42.2,
        longitud: -3.0,
        salidaId: idSalida,
        especie: 'Sylvia atricapilla',
      );
      final idHallazgo1 = await db.insert(
          'hallazgos', hallazgoConSalida.toMap()..remove('id'));
      final idHallazgo2 = await db.insert(
          'hallazgos',
          hallazgoConSalida
              .copyWith(especie: 'Erithacus rubecula')
              .toMap()
            ..remove('id'));

      // Inserta anotación al margen sobre la salida (sin hallazgo).
      await db.insert(
        'anotaciones_diferidas',
        AnotacionDiferida(
          fechaAnotacionMs: 1750500000000,
          salidaId: idSalida,
          texto: 'Anotación de prueba.',
        ).toMap()
          ..remove('id'),
      );

      // Inserta anotación que apunta a hallazgo (no a salida directa).
      await db.insert(
        'anotaciones_diferidas',
        AnotacionDiferida(
          fechaAnotacionMs: 1750500001000,
          salidaId: idSalida,
          hallazgoId: idHallazgo1,
          texto: 'Sobre hallazgo concreto.',
        ).toMap()
          ..remove('id'),
      );

      // Replica la lógica de borrarSalida sin usar el singleton:
      await db.transaction((txn) async {
        await txn.update(
          'hallazgos',
          {'salida_id': null},
          where: 'salida_id = ?',
          whereArgs: [idSalida],
        );
        await txn.update(
          'tracks',
          {'salida_id': null},
          where: 'salida_id = ?',
          whereArgs: [idSalida],
        );
        await txn.delete(
          'anotaciones_diferidas',
          where: 'salida_id = ? AND hallazgo_id IS NULL',
          whereArgs: [idSalida],
        );
        await txn.update(
          'anotaciones_diferidas',
          {'salida_id': null},
          where: 'salida_id = ?',
          whereArgs: [idSalida],
        );
        await txn.delete('salidas', where: 'id = ?', whereArgs: [idSalida]);
      });

      // Verifica: hallazgos siguen ahí pero sin salida_id.
      final filaH1 = (await db.query('hallazgos',
              where: 'id = ?', whereArgs: [idHallazgo1]))
          .first;
      final filaH2 = (await db.query('hallazgos',
              where: 'id = ?', whereArgs: [idHallazgo2]))
          .first;
      expect(filaH1['salida_id'], isNull);
      expect(filaH2['salida_id'], isNull);

      // Anotación sin hallazgo → borrada.
      final filasAnotSinHallazgo = await db.query('anotaciones_diferidas',
          where: 'hallazgo_id IS NULL');
      expect(filasAnotSinHallazgo, isEmpty);

      // Anotación con hallazgo → mantiene texto, salida_id NULL.
      final filasAnotConHallazgo = await db.query('anotaciones_diferidas',
          where: 'hallazgo_id = ?', whereArgs: [idHallazgo1]);
      expect(filasAnotConHallazgo.length, 1);
      expect(filasAnotConHallazgo.first['salida_id'], isNull);

      // Salida → eliminada.
      final filasSalida = await db
          .query('salidas', where: 'id = ?', whereArgs: [idSalida]);
      expect(filasSalida, isEmpty);

      await db.close();
    });

    test('TipoEvidencia.desdeClave es tolerante a valores desconocidos',
        () {
      expect(TipoEvidencia.desdeClave('huella'), TipoEvidencia.huella);
      expect(TipoEvidencia.desdeClave('sonido'), TipoEvidencia.sonido);
      expect(
          TipoEvidencia.desdeClave('XYZ_no_existe'),
          TipoEvidencia.avistamiento,
          reason: 'valor desconocido debe caer a avistamiento');
      expect(TipoEvidencia.desdeClave(null), TipoEvidencia.avistamiento);
    });
  });
}
