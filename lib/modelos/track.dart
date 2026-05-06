class Track {
  final int? id;
  final int fechaMs;
  final String nombre;
  final int? duracionMs;
  final double? distanciaMetros;

  Track({
    this.id,
    required this.fechaMs,
    this.nombre = '',
    this.duracionMs,
    this.distanciaMetros,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha_ms': fechaMs,
        'nombre': nombre,
        'duracion_ms': duracionMs,
        'distancia_metros': distanciaMetros,
      };

  factory Track.fromMap(Map<String, Object?> mapa) => Track(
        id: mapa['id'] as int?,
        fechaMs: mapa['fecha_ms'] as int,
        nombre: (mapa['nombre'] as String?) ?? '',
        duracionMs: mapa['duracion_ms'] as int?,
        distanciaMetros: (mapa['distancia_metros'] as num?)?.toDouble(),
      );
}

class TrackPunto {
  final int? id;
  final int? trackId;
  final int fechaMs;
  final double latitud;
  final double longitud;
  final double? altitud;
  final double? precision;

  TrackPunto({
    this.id,
    this.trackId,
    required this.fechaMs,
    required this.latitud,
    required this.longitud,
    this.altitud,
    this.precision,
  });

  Map<String, Object?> toMap({int? idTrack}) => {
        'id': id,
        'track_id': idTrack ?? trackId,
        'fecha_ms': fechaMs,
        'latitud': latitud,
        'longitud': longitud,
        'altitud': altitud,
        'precision': precision,
      };

  factory TrackPunto.fromMap(Map<String, Object?> mapa) => TrackPunto(
        id: mapa['id'] as int?,
        trackId: mapa['track_id'] as int?,
        fechaMs: mapa['fecha_ms'] as int,
        latitud: (mapa['latitud'] as num).toDouble(),
        longitud: (mapa['longitud'] as num).toDouble(),
        altitud: (mapa['altitud'] as num?)?.toDouble(),
        precision: (mapa['precision'] as num?)?.toDouble(),
      );
}
