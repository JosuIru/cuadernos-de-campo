import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../modelos/hallazgo.dart';
import '../modelos/track.dart';

class BaseDatosFosiles {
  static final BaseDatosFosiles instancia = BaseDatosFosiles._interno();
  factory BaseDatosFosiles() => instancia;
  BaseDatosFosiles._interno();

  Database? _basedatos;
  Completer<Database>? _inicializando;

  Future<Database> get basedatos async {
    if (_basedatos != null) return _basedatos!;
    if (_inicializando != null) return _inicializando!.future;
    _inicializando = Completer<Database>();
    try {
      final directorio = await getApplicationDocumentsDirectory();
      final ruta = path_lib.join(directorio.path, 'fosiles.db');
      _basedatos = await openDatabase(
        ruta,
        version: 7,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE hallazgos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha_ms INTEGER NOT NULL,
            latitud REAL NOT NULL,
            longitud REAL NOT NULL,
            precision REAL,
            especie TEXT,
            edad TEXT,
            formacion TEXT,
            notas TEXT,
            ruta_foto TEXT,
            rutas_fotos_json TEXT,
            contexto_geologico_crudo_json TEXT,
            strike_grados REAL,
            dip_grados REAL,
            tipo TEXT NOT NULL DEFAULT 'fosil',
            trazabilidad_json TEXT,
            firma_descubridor TEXT,
            clave_publica_descubridor TEXT
          )
        ''');
          await db.execute('CREATE INDEX idx_hallazgos_fecha ON hallazgos (fecha_ms DESC)');
          await db.execute('CREATE INDEX idx_hallazgos_tipo ON hallazgos (tipo)');
          await _crearTablasTracks(db);
          await _crearTablaBufferTracks(db);
        },
        onUpgrade: (db, viejo, nuevo) async {
          if (viejo < 2) {
            await db.execute('ALTER TABLE hallazgos ADD COLUMN strike_grados REAL');
            await db.execute('ALTER TABLE hallazgos ADD COLUMN dip_grados REAL');
          }
          if (viejo < 3) {
            await db.execute('ALTER TABLE hallazgos ADD COLUMN rutas_fotos_json TEXT');
            await _crearTablasTracks(db);
            final filas = await db.query('hallazgos', columns: ['id', 'ruta_foto'], where: 'ruta_foto IS NOT NULL');
            for (final fila in filas) {
              final rutas = jsonEncode([fila['ruta_foto']]);
              await db.update('hallazgos', {'rutas_fotos_json': rutas}, where: 'id = ?', whereArgs: [fila['id']]);
            }
          }
          if (viejo < 4) {
            await db.execute("ALTER TABLE hallazgos ADD COLUMN tipo TEXT NOT NULL DEFAULT 'fosil'");
            await db.execute('CREATE INDEX idx_hallazgos_tipo ON hallazgos (tipo)');
          }
          if (viejo < 5) {
            await _crearTablaBufferTracks(db);
          }
          if (viejo < 6) {
            await db.execute('ALTER TABLE hallazgos ADD COLUMN trazabilidad_json TEXT');
          }
          if (viejo < 7) {
            // Fase A del compartir-certificar: identidad criptográfica del
            // descubridor. Hallazgos preexistentes quedan sin firma — la app
            // los marca como "sin firma" en la UI y permite re-firmarlos
            // bajo demanda desde la ficha si el usuario quiere.
            await db.execute('ALTER TABLE hallazgos ADD COLUMN firma_descubridor TEXT');
            await db.execute('ALTER TABLE hallazgos ADD COLUMN clave_publica_descubridor TEXT');
          }
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

  Future<List<Hallazgo>> listarHallazgos() async {
    final db = await basedatos;
    final filas = await db.query('hallazgos', orderBy: 'fecha_ms DESC');
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
    // Eliminar fotos del disco antes de borrar el registro
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
      for (final p in puntos) {
        await txn.insert('track_puntos', p.toMap(idTrack: id)..remove('id'));
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

  Future<void> cerrar() async {
    await _basedatos?.close();
    _basedatos = null;
    _inicializando = null;
  }

  /// Ruta del fichero de BD. Útil para backup.
  Future<String> rutaBaseDatos() async {
    final db = await basedatos;
    return db.path;
  }

  /// Devuelve true si no hay ningún hallazgo guardado (BD vacía).
  Future<bool> estaVacia() async {
    final db = await basedatos;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM hallazgos'));
    return (count ?? 0) == 0;
  }

  /// Cierra y reabre la BD (útil tras restaurar un backup).
  Future<void> reiniciar() async {
    await _basedatos?.close();
    _basedatos = null;
    _inicializando = null;
  }

  // ─── Buffer de grabación incremental de tracks (v5) ─────────────

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

Future<void> _crearTablaBufferTracks(Database db) async {
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
}

Future<void> _crearTablasTracks(Database db) async {
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
