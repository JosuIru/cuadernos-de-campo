import 'licencias_abiertas.dart';

const String baseApiInaturalist = 'https://api.inaturalist.org/v1';

/// Una foto de iNaturalist con licencia abierta y todo lo que hace falta
/// para atribuirla.
class FotoAbierta {
  const FotoAbierta({
    required this.idFoto,
    required this.urlCuadrada,
    required this.autor,
    required this.licencia,
    required this.urlObservacion,
  });

  final int idFoto;

  /// URL de la variante `square` que devuelve la API; las demás tallas se
  /// sacan cambiando solo esa palabra (así lo documenta iNaturalist).
  final String urlCuadrada;
  final String autor;
  final LicenciaAbierta licencia;

  /// Página de la observación en iNaturalist.
  final String urlObservacion;

  String get urlMedia => _talla('medium');
  String get urlGrande => _talla('large');

  /// Página de la foto en iNaturalist (con su licencia).
  String get urlPaginaFoto => 'https://www.inaturalist.org/photos/$idFoto';

  /// «© autor · CC BY» (CC0 sin ©: el autor renunció a sus derechos).
  String get textoAtribucion => licencia == LicenciaAbierta.cc0
      ? '$autor · ${nombreLicencia(licencia)}'
      : '© $autor · ${nombreLicencia(licencia)}';

  String _talla(String talla) => urlCuadrada.replaceFirst(RegExp(r'/square\.'), '/$talla.');

  Map<String, Object?> toJson() => {
        'id': idFoto,
        'url': urlCuadrada,
        'autor': autor,
        'licencia': codigoLicencia(licencia),
        'observacion': urlObservacion,
      };

  static FotoAbierta? fromJson(Object? crudo) {
    if (crudo is! Map) return null;
    final licencia = licenciaAbiertaDesdeCodigo(crudo['licencia'] as String?);
    final id = crudo['id'];
    final url = crudo['url'];
    if (licencia == null || id is! int || url is! String) return null;
    return FotoAbierta(
      idFoto: id,
      urlCuadrada: url,
      autor: (crudo['autor'] as String?) ?? '',
      licencia: licencia,
      urlObservacion: (crudo['observacion'] as String?) ?? 'https://www.inaturalist.org/photos/$id',
    );
  }
}

/// Fotos abiertas de una especie y el taxón de iNaturalist al que
/// pertenecen.
class FotosInaturalist {
  const FotosInaturalist({this.idTaxon, this.fotos = const []});

  final int? idTaxon;
  final List<FotoAbierta> fotos;

  Map<String, Object?> toJson() => {
        'taxon': idTaxon,
        'fotos': [for (final foto in fotos) foto.toJson()],
      };

  static FotosInaturalist fromJson(Object? crudo) {
    if (crudo is! Map) return const FotosInaturalist();
    final fotos = <FotoAbierta>[];
    for (final elemento in (crudo['fotos'] as List?) ?? const []) {
      final foto = FotoAbierta.fromJson(elemento);
      if (foto != null) fotos.add(foto);
    }
    return FotosInaturalist(idTaxon: crudo['taxon'] as int?, fotos: fotos);
  }
}

/// Búsqueda de observaciones de grado investigación con fotos de licencia
/// abierta, ordenadas por votos. Una sola petición por especie.
Uri uriObservacionesConFotosAbiertas(String nombreCientifico, {int porPagina = 12}) =>
    Uri.parse('$baseApiInaturalist/observations').replace(queryParameters: {
      'taxon_name': nombreCientifico.trim(),
      'photo_license': filtroLicenciasInaturalist,
      'quality_grade': 'research',
      'photos': 'true',
      'per_page': '$porPagina',
      'order_by': 'votes',
    });

/// Enlace «Ver en iNaturalist»: la página del taxón si se conoce; si no, la
/// búsqueda por nombre.
Uri uriPaginaInaturalist(String nombreCientifico, {int? idTaxon}) => idTaxon != null
    ? Uri.parse('https://www.inaturalist.org/taxa/$idTaxon')
    : Uri.parse('https://www.inaturalist.org/search').replace(queryParameters: {'q': nombreCientifico.trim()});

/// Extrae de la respuesta de `/observations` hasta [maximoFotos] fotos
/// aceptables (una por observación, para variar de autor y de individuo).
///
/// Una foto se acepta solo si su `license_code` es CC0, CC BY o CC BY-SA
/// **y** está en el dominio abierto de iNaturalist (`inaturalist-open-data`,
/// que según su documentación aloja solo fotos con licencia abierta).
/// Se prefieren las observaciones cuyo taxón es la especie pedida (o una
/// subespecie); si ninguna coincide (sinónimo), valen todas.
FotosInaturalist parsearObservacionesInaturalist(
  Map<String, dynamic> respuesta, {
  required String nombreCientifico,
  int maximoFotos = 8,
}) {
  final observaciones = ((respuesta['results'] as List?) ?? const []).whereType<Map>().toList();
  final buscado = nombreCientifico.trim().toLowerCase();
  bool esDeLaEspecie(Map observacion) {
    final nombre = ((observacion['taxon'] as Map?)?['name'] as String?)?.toLowerCase() ?? '';
    return nombre == buscado || nombre.startsWith('$buscado ');
  }

  final coincidentes = observaciones.where(esDeLaEspecie).toList();
  final elegidas = coincidentes.isNotEmpty ? coincidentes : observaciones;

  int? idTaxon;
  for (final observacion in coincidentes) {
    final taxon = observacion['taxon'] as Map?;
    if ((taxon?['name'] as String?)?.toLowerCase() == buscado) {
      idTaxon = (taxon?['id'] as num?)?.toInt();
      break;
    }
  }

  final fotos = <FotoAbierta>[];
  final idsVistos = <int>{};
  for (final observacion in elegidas) {
    if (fotos.length >= maximoFotos) break;
    final urlObservacion = (observacion['uri'] as String?) ??
        'https://www.inaturalist.org/observations/${observacion['id']}';
    final nombreUsuario = _nombreUsuario(observacion['user']);
    for (final crudo in (observacion['photos'] as List?) ?? const []) {
      if (crudo is! Map) continue;
      final foto = _fotoAceptable(crudo, urlObservacion, nombreUsuario);
      if (foto == null || !idsVistos.add(foto.idFoto)) continue;
      fotos.add(foto);
      break; // una por observación
    }
  }
  return FotosInaturalist(idTaxon: idTaxon, fotos: fotos);
}

FotoAbierta? _fotoAceptable(Map crudo, String urlObservacion, String? nombreUsuario) {
  final licencia = licenciaAbiertaDesdeCodigo(crudo['license_code'] as String?);
  if (licencia == null) return null;
  final id = (crudo['id'] as num?)?.toInt();
  final url = crudo['url'] as String?;
  if (id == null || url == null) return null;
  final anfitrion = Uri.tryParse(url)?.host ?? '';
  if (!anfitrion.contains('inaturalist-open-data')) return null;
  final autor = _autorDeAtribucion(crudo) ?? nombreUsuario;
  if (autor == null || autor.isEmpty) return null; // sin autor no se puede atribuir
  return FotoAbierta(
    idFoto: id,
    urlCuadrada: url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url,
    autor: autor,
    licencia: licencia,
    urlObservacion: urlObservacion,
  );
}

String? _nombreUsuario(Object? usuario) {
  if (usuario is! Map) return null;
  final nombre = (usuario['name'] as String?)?.trim();
  if (nombre != null && nombre.isNotEmpty) return nombre;
  return (usuario['login'] as String?)?.trim();
}

/// Autor según iNaturalist: `attribution_name` o, si no viene, lo que hay
/// entre «(c) » y la primera coma de `attribution`.
String? _autorDeAtribucion(Map crudo) {
  final nombre = (crudo['attribution_name'] as String?)?.trim();
  if (nombre != null && nombre.isNotEmpty) return nombre;
  final atribucion = crudo['attribution'] as String?;
  if (atribucion == null) return null;
  final coincidencia = RegExp(r'^\(c\)\s*([^,]+),').firstMatch(atribucion.trim());
  return coincidencia?.group(1)?.trim();
}
