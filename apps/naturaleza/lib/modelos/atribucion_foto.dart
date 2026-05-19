/// Metadatos de una foto que NO es del usuario — viene de un repositorio
/// externo (Wikipedia Commons, iNaturalist) y respeta CC-BY o CC-BY-SA.
/// Se persiste paralela a [Hallazgo.rutasFotos]: misma posición en la
/// lista, donde `null` significa "foto del usuario, sin atribución".
///
/// Las licencias CC-BY/CC-BY-SA exigen atribución cuando la imagen se
/// reutiliza (export PDF, ZIP, share). Por eso este modelo viaja con
/// la foto, no se descarta.
class AtribucionFoto {
  const AtribucionFoto({
    required this.urlOrigen,
    required this.fuente,
    this.autor,
    this.licencia,
    this.tituloPagina,
  });

  /// URL canónica del recurso de origen (página de descripción en
  /// Wikipedia Commons o página de la observación en iNaturalist).
  /// Sirve para que el usuario pueda volver a la fuente y para
  /// atribuir formalmente al exportar.
  final String urlOrigen;

  /// Identificador de la fuente: `'wikipedia'` o `'inaturalist'`.
  /// Hardcoded en string en lugar de enum para tolerar fuentes
  /// futuras (Flickr, Macaulay…) sin romper compatibilidad de datos
  /// persistidos.
  final String fuente;

  /// Nombre del autor de la foto si la API lo devuelve. iNaturalist
  /// lo da casi siempre; Wikipedia Commons a veces no.
  final String? autor;

  /// Licencia abreviada — `'cc-by-4.0'`, `'cc-by-sa-4.0'`,
  /// `'cc0'`, `'public-domain'`. Sólo se aceptan licencias que
  /// permiten reutilización con atribución.
  final String? licencia;

  /// Título legible del artículo o página. Útil para el badge de UI
  /// y la atribución textual ("según el artículo X de Wikipedia").
  final String? tituloPagina;

  Map<String, Object?> toJson() => {
        'url_origen': urlOrigen,
        'fuente': fuente,
        if (autor != null) 'autor': autor,
        if (licencia != null) 'licencia': licencia,
        if (tituloPagina != null) 'titulo_pagina': tituloPagina,
      };

  static AtribucionFoto? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final mapa = raw.cast<String, Object?>();
    final urlOrigen = mapa['url_origen'] as String?;
    final fuente = mapa['fuente'] as String?;
    if (urlOrigen == null || fuente == null) return null;
    return AtribucionFoto(
      urlOrigen: urlOrigen,
      fuente: fuente,
      autor: mapa['autor'] as String?,
      licencia: mapa['licencia'] as String?,
      tituloPagina: mapa['titulo_pagina'] as String?,
    );
  }

  /// Texto corto para el badge de la UI: "Wikipedia · CC-BY-SA",
  /// "iNaturalist · CC-BY", etc. Si no hay licencia conocida, cae a
  /// solo el nombre de la fuente.
  String etiquetaCorta() {
    final fuenteLegible = fuente == 'wikipedia'
        ? 'Wikipedia'
        : fuente == 'inaturalist'
            ? 'iNaturalist'
            : fuente;
    if (licencia == null || licencia!.isEmpty) return fuenteLegible;
    final licenciaLegible = licencia!.toUpperCase().replaceAll('CC-', 'CC-');
    return '$fuenteLegible · $licenciaLegible';
  }
}
