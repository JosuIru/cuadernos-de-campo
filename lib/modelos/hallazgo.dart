import 'dart:convert';

class Hallazgo {
  final int? id;
  final int fechaMs;
  final double latitud;
  final double longitud;
  final double? precision;
  final String categoria;
  final String especie;
  final String nombreComun;
  final String taxonomia;
  final String habitat;
  final String notas;
  final List<String> rutasFotos;
  final Map<String, dynamic> atributos;

  Hallazgo({
    this.id,
    required this.fechaMs,
    required this.latitud,
    required this.longitud,
    this.precision,
    this.categoria = 'animal',
    this.especie = '',
    this.nombreComun = '',
    this.taxonomia = '',
    this.habitat = '',
    this.notas = '',
    this.rutasFotos = const [],
    this.atributos = const {},
  });

  bool get esAnimal => categoria == 'animal';
  bool get esInsecto => categoria == 'insecto';
  bool get esPlanta => categoria == 'planta';

  String? get rutaFoto => rutasFotos.isEmpty ? null : rutasFotos.first;

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha_ms': fechaMs,
        'latitud': latitud,
        'longitud': longitud,
        'precision': precision,
        'categoria': categoria,
        'especie': especie,
        'nombre_comun': nombreComun,
        'taxonomia': taxonomia,
        'habitat': habitat,
        'notas': notas,
        'rutas_fotos_json': rutasFotos.isEmpty ? null : jsonEncode(rutasFotos),
        'atributos_json': atributos.isEmpty ? null : jsonEncode(atributos),
      };

  factory Hallazgo.fromMap(Map<String, Object?> mapa) {
    final rutasJson = mapa['rutas_fotos_json'] as String?;
    List<String> rutas = const [];
    if (rutasJson != null && rutasJson.isNotEmpty) {
      try {
        rutas = (jsonDecode(rutasJson) as List).cast<String>();
      } catch (_) {
        rutas = const [];
      }
    }
    final atributosJson = mapa['atributos_json'] as String?;
    Map<String, dynamic> atributos = const {};
    if (atributosJson != null && atributosJson.isNotEmpty) {
      try {
        atributos = (jsonDecode(atributosJson) as Map).cast<String, dynamic>();
      } catch (_) {
        atributos = const {};
      }
    }
    return Hallazgo(
      id: mapa['id'] as int?,
      fechaMs: mapa['fecha_ms'] as int,
      latitud: (mapa['latitud'] as num).toDouble(),
      longitud: (mapa['longitud'] as num).toDouble(),
      precision: (mapa['precision'] as num?)?.toDouble(),
      categoria: (mapa['categoria'] as String?) ?? 'animal',
      especie: (mapa['especie'] as String?) ?? '',
      nombreComun: (mapa['nombre_comun'] as String?) ?? '',
      taxonomia: (mapa['taxonomia'] as String?) ?? '',
      habitat: (mapa['habitat'] as String?) ?? '',
      notas: (mapa['notas'] as String?) ?? '',
      rutasFotos: rutas,
      atributos: atributos,
    );
  }

  Hallazgo copyWith({
    String? categoria,
    String? especie,
    String? nombreComun,
    String? taxonomia,
    String? habitat,
    String? notas,
    List<String>? rutasFotos,
    Map<String, dynamic>? atributos,
  }) =>
      Hallazgo(
        id: id,
        fechaMs: fechaMs,
        latitud: latitud,
        longitud: longitud,
        precision: precision,
        categoria: categoria ?? this.categoria,
        especie: especie ?? this.especie,
        nombreComun: nombreComun ?? this.nombreComun,
        taxonomia: taxonomia ?? this.taxonomia,
        habitat: habitat ?? this.habitat,
        notas: notas ?? this.notas,
        rutasFotos: rutasFotos ?? this.rutasFotos,
        atributos: atributos ?? this.atributos,
      );
}
