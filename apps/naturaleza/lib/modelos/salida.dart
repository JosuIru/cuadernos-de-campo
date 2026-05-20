/// Una **salida** es el contenedor narrativo de una jornada de campo:
/// arranca a una hora, opcionalmente lleva un track GPS asociado,
/// agrupa hallazgos creados durante el rato que está abierta y carga
/// la meteorología, la zona y las notas/hipótesis que el operador
/// quiere atar a esa jornada.
///
/// La pieza diferencial frente a apps tipo iNaturalist (registro
/// atómico de observaciones aisladas): aquí la unidad mental es la
/// salida, no la observación.
class Salida {
  final int? id;
  final int fechaInicioMs;
  final int? fechaFinMs;
  final String titulo;
  final String zona;
  final double? meteoTemperaturaC;
  final String meteoResumen;
  final int? altitudAproximada;
  final String notasGenerales;
  final String hipotesisJornada;
  final bool cerrada;

  Salida({
    this.id,
    required this.fechaInicioMs,
    this.fechaFinMs,
    this.titulo = '',
    this.zona = '',
    this.meteoTemperaturaC,
    this.meteoResumen = '',
    this.altitudAproximada,
    this.notasGenerales = '',
    this.hipotesisJornada = '',
    this.cerrada = false,
  });

  bool get enCurso => !cerrada;

  /// Duración real si la salida está cerrada, o duración transcurrida
  /// hasta ahora si sigue abierta.
  int duracionMs([int? ahoraMs]) {
    final fin = fechaFinMs ?? ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    return fin - fechaInicioMs;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha_inicio_ms': fechaInicioMs,
        'fecha_fin_ms': fechaFinMs,
        'titulo': titulo.isEmpty ? null : titulo,
        'zona': zona.isEmpty ? null : zona,
        'meteo_temperatura_c': meteoTemperaturaC,
        'meteo_resumen': meteoResumen.isEmpty ? null : meteoResumen,
        'altitud_aproximada': altitudAproximada,
        'notas_generales':
            notasGenerales.isEmpty ? null : notasGenerales,
        'hipotesis_jornada':
            hipotesisJornada.isEmpty ? null : hipotesisJornada,
        'cerrada': cerrada ? 1 : 0,
      };

  factory Salida.fromMap(Map<String, Object?> mapa) => Salida(
        id: mapa['id'] as int?,
        fechaInicioMs: mapa['fecha_inicio_ms'] as int,
        fechaFinMs: mapa['fecha_fin_ms'] as int?,
        titulo: (mapa['titulo'] as String?) ?? '',
        zona: (mapa['zona'] as String?) ?? '',
        meteoTemperaturaC:
            (mapa['meteo_temperatura_c'] as num?)?.toDouble(),
        meteoResumen: (mapa['meteo_resumen'] as String?) ?? '',
        altitudAproximada: mapa['altitud_aproximada'] as int?,
        notasGenerales: (mapa['notas_generales'] as String?) ?? '',
        hipotesisJornada: (mapa['hipotesis_jornada'] as String?) ?? '',
        cerrada: ((mapa['cerrada'] as int?) ?? 0) == 1,
      );

  Salida copyWith({
    int? fechaFinMs,
    String? titulo,
    String? zona,
    double? meteoTemperaturaC,
    String? meteoResumen,
    int? altitudAproximada,
    String? notasGenerales,
    String? hipotesisJornada,
    bool? cerrada,
  }) =>
      Salida(
        id: id,
        fechaInicioMs: fechaInicioMs,
        fechaFinMs: fechaFinMs ?? this.fechaFinMs,
        titulo: titulo ?? this.titulo,
        zona: zona ?? this.zona,
        meteoTemperaturaC: meteoTemperaturaC ?? this.meteoTemperaturaC,
        meteoResumen: meteoResumen ?? this.meteoResumen,
        altitudAproximada: altitudAproximada ?? this.altitudAproximada,
        notasGenerales: notasGenerales ?? this.notasGenerales,
        hipotesisJornada: hipotesisJornada ?? this.hipotesisJornada,
        cerrada: cerrada ?? this.cerrada,
      );
}
