import 'dart:convert';

import 'atribucion_foto.dart';

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

  /// Atribución por foto, paralela a [rutasFotos]: misma longitud,
  /// `null` en la posición = foto del usuario (sin atribución), no-null
  /// = foto de archivo descargada de Wikipedia/iNaturalist con su
  /// licencia. Se persiste dentro de [atributos] bajo la clave
  /// `atribuciones_fotos` — sin migración del esquema sqlite.
  ///
  /// Lista vacía o longitud distinta a `rutasFotos` se trata como
  /// "ninguna foto tiene atribución" (todas del usuario).
  final List<AtribucionFoto?> atribucionesFotos;

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
    this.atribucionesFotos = const [],
    this.atributos = const {},
  });

  bool get esAnimal => categoria == 'animal';
  bool get esInsecto => categoria == 'insecto';
  bool get esPlanta => categoria == 'planta';

  String? get rutaFoto => rutasFotos.isEmpty ? null : rutasFotos.first;

  /// Atribución de la foto en posición [indice], o `null` si:
  /// - el índice está fuera de rango,
  /// - la lista paralela no se rellenó (foto del usuario).
  AtribucionFoto? atribucionEnPosicion(int indice) {
    if (indice < 0 || indice >= atribucionesFotos.length) return null;
    return atribucionesFotos[indice];
  }

  Map<String, Object?> toMap() {
    final atributosCompleto = <String, dynamic>{...atributos};
    // Sólo persistimos la lista paralela si alguna foto tiene
    // atribución — evita ensuciar registros antiguos con un campo
    // vacío que no aporta nada.
    final hayAtribucion = atribucionesFotos.any((a) => a != null);
    if (hayAtribucion) {
      atributosCompleto['atribuciones_fotos'] = atribucionesFotos
          .map((a) => a?.toJson())
          .toList();
    }
    return {
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
      'rutas_fotos_json':
          rutasFotos.isEmpty ? null : jsonEncode(rutasFotos),
      'atributos_json':
          atributosCompleto.isEmpty ? null : jsonEncode(atributosCompleto),
    };
  }

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
        atributos =
            (jsonDecode(atributosJson) as Map).cast<String, dynamic>();
      } catch (_) {
        atributos = const {};
      }
    }
    // Extraemos la lista paralela de atribuciones del Map atributos
    // y la sacamos de allí para no duplicar cuando se vuelva a
    // serializar — toMap la regenera desde el campo `atribucionesFotos`.
    List<AtribucionFoto?> atribuciones = const [];
    final atribsRaw = atributos['atribuciones_fotos'];
    if (atribsRaw is List) {
      atribuciones = atribsRaw.map(AtribucionFoto.fromJson).toList();
      atributos = Map<String, dynamic>.from(atributos)
        ..remove('atribuciones_fotos');
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
      atribucionesFotos: atribuciones,
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
    List<AtribucionFoto?>? atribucionesFotos,
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
        atribucionesFotos: atribucionesFotos ?? this.atribucionesFotos,
        atributos: atributos ?? this.atributos,
      );
}
