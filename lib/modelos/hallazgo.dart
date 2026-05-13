import 'dart:convert';

import '../servicios/autoridad_certificadora.dart' show Certificacion;

class EventoTrazabilidad {
  final int fechaMs;
  final String tipo; // 'deposito_museo', 'estudio', 'publicacion', 'otro'
  final String descripcion;
  final String autor;

  EventoTrazabilidad({
    required this.fechaMs,
    required this.tipo,
    required this.descripcion,
    required this.autor,
  });

  Map<String, dynamic> toJson() => {
        'f': fechaMs,
        't': tipo,
        'd': descripcion,
        'a': autor,
      };

  factory EventoTrazabilidad.fromJson(Map<String, dynamic> json) => EventoTrazabilidad(
        fechaMs: json['f'] as int,
        tipo: json['t'] as String,
        descripcion: json['d'] as String,
        autor: json['a'] as String,
      );

  static const tiposDisponibles = [
    ('deposito_museo', 'Depositado en museo / colección'),
    ('estudio', 'Estudiado por'),
    ('publicacion', 'Citado en publicación'),
    ('prestamo', 'Préstamo / consulta'),
    ('otro', 'Otro evento'),
  ];
}

class Hallazgo {
  final int? id;
  final int fechaMs;
  final double latitud;
  final double longitud;
  final double? precision;
  final String especie;
  final String edad;
  final String formacion;
  final String notas;
  final List<String> rutasFotos;
  final String? contextoGeologicoCrudoJson;
  final double? strikeGrados;
  final double? dipGrados;
  final String tipo; // 'fosil' o 'mineral'
  final List<EventoTrazabilidad> historialTrazabilidad;

  /// Firma Ed25519 (base64) de los datos canónicos del hallazgo, generada
  /// con la clave privada del descubridor al crearlo. Permite verificar
  /// offline que el hallazgo no ha sido modificado desde su creación.
  /// Null en hallazgos pre-Fase A o creados sin identidad.
  final String? firmaDescubridor;

  /// Clave pública Ed25519 (base64) del descubridor en el momento de
  /// firmar. Va siempre acompañando a [firmaDescubridor] — se incluye en
  /// el propio hallazgo (no se busca por id de usuario) para que la card
  /// sea autocontenida al exportarla.
  final String? clavePublicaDescubridor;

  /// Cadena de certificaciones añadidas sobre el hallazgo por autoridades
  /// firmantes (Instituto Nacional de Geología, museos, sociedades). Cada
  /// certificación firma el hash del estado anterior (firma del
  /// descubridor + certificaciones previas), formando una cadena
  /// verificable hacia atrás. Vacía mientras nadie haya certificado.
  final List<Certificacion> certificaciones;

  Hallazgo({
    this.id,
    required this.fechaMs,
    required this.latitud,
    required this.longitud,
    this.precision,
    this.especie = '',
    this.edad = '',
    this.formacion = '',
    this.notas = '',
    this.rutasFotos = const [],
    this.contextoGeologicoCrudoJson,
    this.strikeGrados,
    this.dipGrados,
    this.tipo = 'fosil',
    this.historialTrazabilidad = const [],
    this.firmaDescubridor,
    this.clavePublicaDescubridor,
    this.certificaciones = const [],
  });

  bool get esMineral => tipo == 'mineral';

  /// True si el hallazgo viene firmado criptográficamente por el descubridor.
  bool get tieneFirma =>
      firmaDescubridor != null &&
      firmaDescubridor!.isNotEmpty &&
      clavePublicaDescubridor != null &&
      clavePublicaDescubridor!.isNotEmpty;

  /// True si el hallazgo lleva al menos una certificación de tipo
  /// 'certificacion' (no sólo acuses o descartes) — basta para pintar el
  /// sello dorado "◆ ING" en la UI.
  bool get estaCertificado =>
      certificaciones.any((c) => c.tipo.name == 'certificacion');

  String? get rutaFoto => rutasFotos.isEmpty ? null : rutasFotos.first;

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha_ms': fechaMs,
        'latitud': latitud,
        'longitud': longitud,
        'precision': precision,
        'especie': especie,
        'edad': edad,
        'formacion': formacion,
        'notas': notas,
        'ruta_foto': rutasFotos.isEmpty ? null : rutasFotos.first,
        'rutas_fotos_json': rutasFotos.isEmpty ? null : jsonEncode(rutasFotos),
        'contexto_geologico_crudo_json': contextoGeologicoCrudoJson,
        'strike_grados': strikeGrados,
        'dip_grados': dipGrados,
        'tipo': tipo,
        'trazabilidad_json': historialTrazabilidad.isEmpty
            ? null
            : jsonEncode(historialTrazabilidad.map((e) => e.toJson()).toList()),
        'firma_descubridor': firmaDescubridor,
        'clave_publica_descubridor': clavePublicaDescubridor,
        'certificaciones_json': certificaciones.isEmpty
            ? null
            : jsonEncode(certificaciones.map((c) => c.toJson()).toList()),
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
    } else {
      final unica = mapa['ruta_foto'] as String?;
      if (unica != null && unica.isNotEmpty) rutas = [unica];
    }
    return Hallazgo(
      id: mapa['id'] as int?,
      fechaMs: mapa['fecha_ms'] as int,
      latitud: (mapa['latitud'] as num).toDouble(),
      longitud: (mapa['longitud'] as num).toDouble(),
      precision: (mapa['precision'] as num?)?.toDouble(),
      especie: (mapa['especie'] as String?) ?? '',
      edad: (mapa['edad'] as String?) ?? '',
      formacion: (mapa['formacion'] as String?) ?? '',
      notas: (mapa['notas'] as String?) ?? '',
      rutasFotos: rutas,
      contextoGeologicoCrudoJson: mapa['contexto_geologico_crudo_json'] as String?,
      strikeGrados: (mapa['strike_grados'] as num?)?.toDouble(),
      dipGrados: (mapa['dip_grados'] as num?)?.toDouble(),
      tipo: (mapa['tipo'] as String?) ?? 'fosil',
      historialTrazabilidad: _parsearTrazabilidad(mapa['trazabilidad_json'] as String?),
      firmaDescubridor: mapa['firma_descubridor'] as String?,
      clavePublicaDescubridor: mapa['clave_publica_descubridor'] as String?,
      certificaciones: _parsearCertificaciones(mapa['certificaciones_json'] as String?),
    );
  }

  static List<Certificacion> _parsearCertificaciones(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final lista = jsonDecode(json) as List;
      return lista
          .map((e) => Certificacion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<EventoTrazabilidad> _parsearTrazabilidad(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final lista = jsonDecode(json) as List;
      return lista
          .map((e) => EventoTrazabilidad.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Hallazgo copyWith({
    String? especie,
    String? edad,
    String? formacion,
    String? notas,
    List<String>? rutasFotos,
    double? strikeGrados,
    double? dipGrados,
    String? tipo,
    List<EventoTrazabilidad>? historialTrazabilidad,
    String? firmaDescubridor,
    String? clavePublicaDescubridor,
    List<Certificacion>? certificaciones,
  }) =>
      Hallazgo(
        id: id,
        fechaMs: fechaMs,
        latitud: latitud,
        longitud: longitud,
        precision: precision,
        especie: especie ?? this.especie,
        edad: edad ?? this.edad,
        formacion: formacion ?? this.formacion,
        notas: notas ?? this.notas,
        rutasFotos: rutasFotos ?? this.rutasFotos,
        contextoGeologicoCrudoJson: contextoGeologicoCrudoJson,
        strikeGrados: strikeGrados ?? this.strikeGrados,
        dipGrados: dipGrados ?? this.dipGrados,
        tipo: tipo ?? this.tipo,
        historialTrazabilidad: historialTrazabilidad ?? this.historialTrazabilidad,
        firmaDescubridor: firmaDescubridor ?? this.firmaDescubridor,
        clavePublicaDescubridor: clavePublicaDescubridor ?? this.clavePublicaDescubridor,
        certificaciones: certificaciones ?? this.certificaciones,
      );
}
