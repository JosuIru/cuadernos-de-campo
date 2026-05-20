import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../modelos/hallazgo.dart';
import '../modelos/track.dart';
import '../modelos/salida.dart';
import '../modelos/anotacion_diferida.dart';

class BaseDatosNaturaleza {
  static final BaseDatosNaturaleza instancia = BaseDatosNaturaleza._interno();
  factory BaseDatosNaturaleza() => instancia;
  BaseDatosNaturaleza._interno();

  Database? _basedatos;
  Completer<Database>? _inicializando;

  Future<Database> get basedatos async {
    if (_basedatos != null) return _basedatos!;
    if (_inicializando != null) return _inicializando!.future;
    _inicializando = Completer<Database>();
    try {
      final directorio = await getApplicationDocumentsDirectory();
      final ruta = path_lib.join(directorio.path, 'naturaleza.db');
      _basedatos = await openDatabase(
        ruta,
        version: 3,
        onCreate: (db, version) async {
          await crearEsquemaInicial(db);
          await aplicarMigraciones(db, desde: 1, hasta: version);
        },
        onUpgrade: (db, anterior, actual) async {
          await aplicarMigraciones(db, desde: anterior, hasta: actual);
        },
      );
      _inicializando!.complete(_basedatos!);
      return _basedatos!;
    } catch (e) {
      _inicializando!.completeError(e);
      _inicializando = null;
      rethrow;
    }
  }

  Future<int> guardarHallazgo(Hallazgo hallazgo) async {
    final db = await basedatos;
    return await db.insert('hallazgos', hallazgo.toMap()..remove('id'));
  }

  Future<void> actualizarHallazgo(int id, Map<String, Object?> cambios) async {
    final db = await basedatos;
    await db.update('hallazgos', cambios, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Hallazgo>> listarHallazgos({String? categoria}) async {
    final db = await basedatos;
    final filas = await db.query(
      'hallazgos',
      where: categoria != null ? 'categoria = ?' : null,
      whereArgs: categoria != null ? [categoria] : null,
      orderBy: 'fecha_ms DESC',
    );
    return filas.map(Hallazgo.fromMap).toList();
  }

  Future<Hallazgo?> obtenerHallazgo(int id) async {
    final db = await basedatos;
    final filas = await db.query('hallazgos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    return Hallazgo.fromMap(filas.first);
  }

  Future<void> borrarHallazgo(int id) async {
    final db = await basedatos;
    try {
      final filas = await db.query('hallazgos', columns: ['rutas_fotos_json'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (filas.isNotEmpty) {
        final json = filas.first['rutas_fotos_json'] as String?;
        if (json != null && json.isNotEmpty) {
          final rutas = (jsonDecode(json) as List).cast<String>();
          for (final ruta in rutas) {
            try { await File(ruta).delete(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
    await db.delete('hallazgos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> guardarTrack(Track track, List<TrackPunto> puntos) async {
    final db = await basedatos;
    return await db.transaction<int>((txn) async {
      final id = await txn.insert('tracks', track.toMap()..remove('id'));
      for (final punto in puntos) {
        await txn.insert('track_puntos', punto.toMap(idTrack: id)..remove('id'));
      }
      return id;
    });
  }

  Future<List<Track>> listarTracks() async {
    final db = await basedatos;
    final filas = await db.query('tracks', orderBy: 'fecha_ms DESC');
    return filas.map(Track.fromMap).toList();
  }

  Future<List<TrackPunto>> obtenerPuntosTrack(int idTrack) async {
    final db = await basedatos;
    final filas = await db.query('track_puntos', where: 'track_id = ?', whereArgs: [idTrack], orderBy: 'fecha_ms ASC');
    return filas.map(TrackPunto.fromMap).toList();
  }

  Future<void> borrarTrack(int id) async {
    final db = await basedatos;
    await db.transaction((txn) async {
      await txn.delete('track_puntos', where: 'track_id = ?', whereArgs: [id]);
      await txn.delete('tracks', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Salidas (v3) ─────────────────────────────────────────────────

  /// Persiste una salida nueva y devuelve su id.
  Future<int> guardarSalida(Salida salida) async {
    final db = await basedatos;
    return await db.insert('salidas', salida.toMap()..remove('id'));
  }

  /// Actualiza campos puntuales de una salida ya existente.
  Future<void> actualizarSalida(int id, Map<String, Object?> cambios) async {
    final db = await basedatos;
    await db.update('salidas', cambios, where: 'id = ?', whereArgs: [id]);
  }

  /// Marca una salida como cerrada y registra la hora fin. Idempotente:
  /// si ya está cerrada respeta la fecha_fin_ms existente.
  Future<void> cerrarSalida(int id, {int? fechaFinMs}) async {
    final db = await basedatos;
    final fin = fechaFinMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'salidas',
      {'cerrada': 1, 'fecha_fin_ms': fin},
      where: 'id = ? AND cerrada = 0',
      whereArgs: [id],
    );
  }

  /// Devuelve la salida activa (cerrada = 0) más reciente, o null si
  /// no hay ninguna abierta. La app sólo permite una salida en curso
  /// a la vez (el flujo de UI lo refuerza).
  Future<Salida?> salidaEnCurso() async {
    final db = await basedatos;
    final filas = await db.query(
      'salidas',
      where: 'cerrada = 0',
      orderBy: 'fecha_inicio_ms DESC',
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Salida.fromMap(filas.first);
  }

  Future<List<Salida>> listarSalidas() async {
    final db = await basedatos;
    final filas = await db.query(
      'salidas',
      orderBy: 'fecha_inicio_ms DESC',
    );
    return filas.map(Salida.fromMap).toList();
  }

  Future<Salida?> obtenerSalida(int id) async {
    final db = await basedatos;
    final filas = await db.query(
      'salidas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Salida.fromMap(filas.first);
  }

  /// Borra la salida y desasocia (SET NULL) hallazgos, tracks y
  /// anotaciones diferidas que colgaban de ella. No borra los
  /// hallazgos ni tracks — pasan a sueltos. Las anotaciones diferidas
  /// sí se borran si quedaran huérfanas (sin hallazgo y sin salida).
  Future<void> borrarSalida(int id) async {
    final db = await basedatos;
    await db.transaction((txn) async {
      await txn.update(
        'hallazgos',
        {'salida_id': null},
        where: 'salida_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'tracks',
        {'salida_id': null},
        where: 'salida_id = ?',
        whereArgs: [id],
      );
      // Anotaciones diferidas que sólo cuelgan de la salida quedarían
      // huérfanas → borrarlas. Las que también apuntan a un hallazgo
      // se mantienen con salida_id NULL.
      await txn.delete(
        'anotaciones_diferidas',
        where: 'salida_id = ? AND hallazgo_id IS NULL',
        whereArgs: [id],
      );
      await txn.update(
        'anotaciones_diferidas',
        {'salida_id': null},
        where: 'salida_id = ?',
        whereArgs: [id],
      );
      await txn.delete('salidas', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Cuenta hallazgos asociados a una salida. Usado en la pantalla
  /// lista para mostrar "N hallazgos" por cabecera.
  Future<int> contarHallazgosDeSalida(int salidaId) async {
    final db = await basedatos;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM hallazgos WHERE salida_id = ?',
      [salidaId],
    ));
    return count ?? 0;
  }

  /// Hallazgos pertenecientes a una salida, en orden cronológico
  /// ascendente (como se anotaron en la jornada).
  Future<List<Hallazgo>> hallazgosDeSalida(int salidaId) async {
    final db = await basedatos;
    final filas = await db.query(
      'hallazgos',
      where: 'salida_id = ?',
      whereArgs: [salidaId],
      orderBy: 'fecha_ms ASC',
    );
    return filas.map(Hallazgo.fromMap).toList();
  }

  /// Track asociado a una salida, si lo hay. Convención: una salida
  /// tiene como máximo un track.
  Future<Track?> trackDeSalida(int salidaId) async {
    final db = await basedatos;
    final filas = await db.query(
      'tracks',
      where: 'salida_id = ?',
      whereArgs: [salidaId],
      orderBy: 'fecha_ms ASC',
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Track.fromMap(filas.first);
  }

  // ─── Anotaciones diferidas (v3) ───────────────────────────────────

  Future<int> guardarAnotacionDiferida(AnotacionDiferida anotacion) async {
    final db = await basedatos;
    return await db.insert(
      'anotaciones_diferidas',
      anotacion.toMap()..remove('id'),
    );
  }

  Future<List<AnotacionDiferida>> anotacionesDeSalida(int salidaId) async {
    final db = await basedatos;
    final filas = await db.query(
      'anotaciones_diferidas',
      where: 'salida_id = ?',
      whereArgs: [salidaId],
      orderBy: 'fecha_anotacion_ms ASC',
    );
    return filas.map(AnotacionDiferida.fromMap).toList();
  }

  Future<List<AnotacionDiferida>> anotacionesDeHallazgo(
      int hallazgoId) async {
    final db = await basedatos;
    final filas = await db.query(
      'anotaciones_diferidas',
      where: 'hallazgo_id = ?',
      whereArgs: [hallazgoId],
      orderBy: 'fecha_anotacion_ms ASC',
    );
    return filas.map(AnotacionDiferida.fromMap).toList();
  }

  Future<void> borrarAnotacionDiferida(int id) async {
    final db = await basedatos;
    await db.delete('anotaciones_diferidas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cerrar() async {
    await _basedatos?.close();
    _basedatos = null;
    _inicializando = null;
  }

  Future<String> rutaBaseDatos() async {
    final db = await basedatos;
    return db.path;
  }

  Future<bool> estaVacia() async {
    final db = await basedatos;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM hallazgos'));
    return (count ?? 0) == 0;
  }

  Future<void> reiniciar() async {
    await _basedatos?.close();
    _basedatos = null;
    _inicializando = null;
  }

  // ─── Buffer de grabación incremental de tracks (v2) ─────────────

  /// Persiste un punto GPS del track actual al buffer de la BD para
  /// que sobreviva a un crash o kill OS. [inicioMs] identifica la
  /// sesión activa (timestamp de comienzo); todos los puntos de la
  /// misma grabación comparten ese inicio.
  Future<void> bufferarPuntoTrack({
    required int inicioMs,
    required TrackPunto punto,
  }) async {
    final db = await basedatos;
    await db.insert('track_grabacion_buffer', {
      'inicio_ms': inicioMs,
      'fecha_ms': punto.fechaMs,
      'latitud': punto.latitud,
      'longitud': punto.longitud,
      'altitud': punto.altitud,
      'precision': punto.precision,
    });
  }

  /// Recupera puntos del buffer para [inicioMs]. Si [inicioMs] es
  /// null, devuelve todos los puntos de cualquier sesión incompleta
  /// (caso típico de recuperación al arrancar la app tras crash).
  Future<List<TrackPunto>> recuperarBufferTrack({int? inicioMs}) async {
    final db = await basedatos;
    final filas = await db.query(
      'track_grabacion_buffer',
      where: inicioMs != null ? 'inicio_ms = ?' : null,
      whereArgs: inicioMs != null ? [inicioMs] : null,
      orderBy: 'fecha_ms ASC',
    );
    return filas.map((fila) => TrackPunto(
          fechaMs: fila['fecha_ms'] as int,
          latitud: fila['latitud'] as double,
          longitud: fila['longitud'] as double,
          altitud: fila['altitud'] as double?,
          precision: fila['precision'] as double?,
        )).toList();
  }

  /// Devuelve los `inicio_ms` distintos en el buffer (sesiones
  /// incompletas pendientes de cerrar). Lista vacía si no hay nada
  /// que recuperar.
  Future<List<int>> sesionesPendientesEnBuffer() async {
    final db = await basedatos;
    final filas = await db.rawQuery(
      'SELECT DISTINCT inicio_ms FROM track_grabacion_buffer ORDER BY inicio_ms ASC',
    );
    return filas.map((f) => f['inicio_ms'] as int).toList();
  }

  /// Vacía el buffer de la sesión [inicioMs]. Si es null, vacía
  /// todo (útil al cancelar o tras consolidar a un track persistido).
  Future<void> vaciarBufferTrack({int? inicioMs}) async {
    final db = await basedatos;
    await db.delete(
      'track_grabacion_buffer',
      where: inicioMs != null ? 'inicio_ms = ?' : null,
      whereArgs: inicioMs != null ? [inicioMs] : null,
    );
  }
}

/// Esquema inicial (v1) — expuesto sin underscore para que los tests
/// de migración puedan recrearlo sobre bases de datos en memoria.
Future<void> crearEsquemaInicial(Database db) async {
  await db.execute('''
    CREATE TABLE hallazgos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha_ms INTEGER NOT NULL,
      latitud REAL NOT NULL,
      longitud REAL NOT NULL,
      precision REAL,
      categoria TEXT NOT NULL DEFAULT 'animal',
      especie TEXT,
      nombre_comun TEXT,
      taxonomia TEXT,
      habitat TEXT,
      notas TEXT,
      rutas_fotos_json TEXT,
      atributos_json TEXT
    )
  ''');
  await db.execute('CREATE INDEX idx_hallazgos_fecha ON hallazgos (fecha_ms DESC)');
  await db.execute('CREATE INDEX idx_hallazgos_categoria ON hallazgos (categoria)');
  await db.execute('''
    CREATE TABLE tracks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha_ms INTEGER NOT NULL,
      nombre TEXT,
      duracion_ms INTEGER,
      distancia_metros REAL
    )
  ''');
  await db.execute('''
    CREATE TABLE track_puntos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      track_id INTEGER NOT NULL,
      fecha_ms INTEGER NOT NULL,
      latitud REAL NOT NULL,
      longitud REAL NOT NULL,
      altitud REAL,
      precision REAL,
      FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_track_puntos_track ON track_puntos (track_id, fecha_ms)');
}

/// Aplica las migraciones de esquema en orden, desde la versión
/// [desde] (excluida) hasta [hasta] (incluida). Cada paso debe ser
/// idempotente y nunca destructivo: las apps en campo no pueden
/// perder datos por una actualización.
Future<void> aplicarMigraciones(Database db,
    {required int desde, required int hasta}) async {
  for (var v = desde + 1; v <= hasta; v++) {
    switch (v) {
      case 2:
        // v2 añade tabla de buffer para tracks en grabación. Permite
        // persistir incrementalmente puntos GPS y recuperar la sesión
        // si la app muere durante la grabación.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS track_grabacion_buffer (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inicio_ms INTEGER NOT NULL,
            fecha_ms INTEGER NOT NULL,
            latitud REAL NOT NULL,
            longitud REAL NOT NULL,
            altitud REAL,
            precision REAL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_buffer_inicio ON track_grabacion_buffer (inicio_ms, fecha_ms)',
        );
        break;
      case 3:
        // v3 introduce el concepto de "salida": contenedor narrativo
        // de una jornada de campo (track GPS + N hallazgos + meteo +
        // notas + hipótesis). Salidas y hallazgos viejos siguen
        // funcionando: salida_id es nullable y todos los hallazgos
        // existentes quedan como hallazgos sueltos.
        //
        // También enriquece hallazgos con tipo_evidencia (huellas,
        // plumas, sonido, etc. son ciudadanos de primera clase, no
        // sólo "vi al bicho"), hipótesis personal y validación
        // posterior de la identificación.
        //
        // Y la tabla anotaciones_diferidas captura el gesto físico del
        // cuaderno: anotar al margen días después.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salidas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha_inicio_ms INTEGER NOT NULL,
            fecha_fin_ms INTEGER,
            titulo TEXT,
            zona TEXT,
            meteo_temperatura_c REAL,
            meteo_resumen TEXT,
            altitud_aproximada INTEGER,
            notas_generales TEXT,
            hipotesis_jornada TEXT,
            cerrada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_salidas_fecha ON salidas (fecha_inicio_ms DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_salidas_cerrada ON salidas (cerrada)',
        );

        // ALTER TABLE en SQLite: una columna por sentencia, nullable
        // o con default explícito (NOT NULL requiere default).
        await db.execute('ALTER TABLE hallazgos ADD COLUMN salida_id INTEGER');
        await db.execute(
          "ALTER TABLE hallazgos ADD COLUMN tipo_evidencia TEXT NOT NULL DEFAULT 'avistamiento'",
        );
        await db.execute('ALTER TABLE hallazgos ADD COLUMN hipotesis TEXT');
        await db.execute(
          'ALTER TABLE hallazgos ADD COLUMN confianza_identificacion TEXT',
        );
        await db.execute(
          'ALTER TABLE hallazgos ADD COLUMN identificacion_validada INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE hallazgos ADD COLUMN especie_corregida TEXT',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_hallazgos_salida ON hallazgos (salida_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_hallazgos_tipo_evidencia ON hallazgos (tipo_evidencia)',
        );

        await db.execute('ALTER TABLE tracks ADD COLUMN salida_id INTEGER');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tracks_salida ON tracks (salida_id)',
        );

        // ON DELETE de salida no se confía a SQLite (PRAGMA
        // foreign_keys puede no estar activo). El borrado pone los
        // FKs a NULL desde el código.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS anotaciones_diferidas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha_anotacion_ms INTEGER NOT NULL,
            salida_id INTEGER,
            hallazgo_id INTEGER,
            texto TEXT NOT NULL,
            CHECK (salida_id IS NOT NULL OR hallazgo_id IS NOT NULL)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_anotaciones_salida ON anotaciones_diferidas (salida_id, fecha_anotacion_ms)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_anotaciones_hallazgo ON anotaciones_diferidas (hallazgo_id, fecha_anotacion_ms)',
        );
        break;
    }
  }
}
