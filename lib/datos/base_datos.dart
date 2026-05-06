import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../modelos/hallazgo.dart';
import '../modelos/track.dart';

class BaseDatosNaturaleza {
  static final BaseDatosNaturaleza instancia = BaseDatosNaturaleza._interno();
  factory BaseDatosNaturaleza() => instancia;
  BaseDatosNaturaleza._interno();

  Database? _basedatos;

  Future<Database> get basedatos async {
    if (_basedatos != null) return _basedatos!;
    final directorio = await getApplicationDocumentsDirectory();
    final ruta = path_lib.join(directorio.path, 'naturaleza.db');
    _basedatos = await openDatabase(
      ruta,
      version: 1,
      onCreate: (db, version) async {
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
        await _crearTablasTracks(db);
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
