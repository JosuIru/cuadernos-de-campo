/// Foto aprobada por un curador para una formación geológica concreta.
/// Lo que la app recibe del backend en `GET /fotos-comunidad/por-formacion/{codigo}`.
///
/// NUNCA contiene datos de identidad del aficionado que la subió ni
/// coordenadas — esos datos se quedan en el backend, accesibles solo al
/// curador.
class FotoComunidad {
  /// Identificador estable en backend.
  final int id;

  /// Código (slug) de la formación geológica catalogada a la que está
  /// asociada esta foto (p. ej. `'calizas-urgonianas-aralar'`).
  final String formacionCodigo;

  /// Tipo de hallazgo: `'fosil'` o `'mineral'`.
  final String tipo;

  /// Especie/grupo según la edición del curador (puede haber corregido
  /// la declaración original del aficionado).
  final String especieCurada;

  /// Edad geológica según el curador.
  final String edadCurada;

  /// Notas del curador (contexto pedagógico, advertencias, etc.).
  final String comentariosCurador;

  /// URL absoluta de la foto a tamaño completo.
  final String fotoUrl;

  /// URL absoluta del thumbnail (~256px). Si el backend no genera
  /// thumbnails separados, devuelve la misma URL que `fotoUrl`.
  final String thumbnailUrl;

  /// Timestamp UNIX (segundos) de cuándo fue aprobada.
  final int fechaAprobacionSegundos;

  const FotoComunidad({
    required this.id,
    required this.formacionCodigo,
    required this.tipo,
    required this.especieCurada,
    required this.edadCurada,
    required this.comentariosCurador,
    required this.fotoUrl,
    required this.thumbnailUrl,
    required this.fechaAprobacionSegundos,
  });

  factory FotoComunidad.desdeJson(Map<String, dynamic> json) {
    return FotoComunidad(
      id: json['id'] as int,
      formacionCodigo: json['formacion_codigo'] as String,
      tipo: json['tipo'] as String,
      especieCurada: json['especie_curada'] as String? ?? '',
      edadCurada: json['edad_curada'] as String? ?? '',
      comentariosCurador: json['comentarios_curador'] as String? ?? '',
      fotoUrl: json['foto_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String? ?? json['foto_url'] as String,
      fechaAprobacionSegundos: json['fecha_aprobacion'] as int? ?? 0,
    );
  }
}

/// Resultado de subir una aportación. El cliente solo necesita saber
/// que se aceptó y queda pendiente de revisión.
class ResultadoSubidaAportacion {
  /// Identificador asignado por el backend. Útil para reportes / debug.
  final int idAportacion;

  /// Estado inicial — debe ser `'pendiente'` salvo error en backend.
  final String estado;

  const ResultadoSubidaAportacion({
    required this.idAportacion,
    required this.estado,
  });

  factory ResultadoSubidaAportacion.desdeJson(Map<String, dynamic> json) {
    return ResultadoSubidaAportacion(
      idAportacion: json['id'] as int,
      estado: json['estado'] as String? ?? 'pendiente',
    );
  }
}
