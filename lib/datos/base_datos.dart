import 'dart:convert';
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

  Future<Database> get basedatos async {
    if (_basedatos != null) return _basedatos!;
    final directorio = await getApplicationDocumentsDirectory();
    final ruta = path_lib.join(directorio.path, 'fosiles.db');
    _basedatos = await openDatabase(
      ruta,
      version: 4,
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
            tipo TEXT NOT NULL DEFAULT 'fosil'
          )
        ''');
        await db.execute('CREATE INDEX idx_hallazgos_fecha ON hallazgos (fecha_ms DESC)');
        await db.execute('CREATE INDEX idx_hallazgos_tipo ON hallazgos (tipo)');
        await _crearTablasTracks(db);
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
      },
    );
    return _basedatos!;
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
  }
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
