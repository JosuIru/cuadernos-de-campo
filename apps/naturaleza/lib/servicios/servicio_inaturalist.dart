import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nuevo_ser_core/nuevo_ser_core.dart' show SoleraL10n;

import '../fuentes_abiertas/licencias_abiertas.dart';

const _baseInaturalist = 'https://api.inaturalist.org/v1';
const _cabecerasInaturalist = {
  'User-Agent': 'naturaleza-flutter/1.0 (https://github.com/josu/naturaleza-flutter)',
  'Accept': 'application/json',
};

class ResultadoTaxonInaturalist {
  final int id;
  final String nombreCientifico;
  final String? nombreComun;
  final String? rangoTaxonomico;
  /// Foto por defecto del taxón, solo si su licencia es CC0, CC BY o
  /// CC BY-SA (ver [fotoPorDefectoAbierta]).
  final String? urlFoto;

  /// «© autor · licencia» de [urlFoto].
  final String? atribucionFoto;
  final String? reino;

  /// Valor crudo de `iconic_taxon_name` que devuelve iNaturalist
  /// (ej. `'Aves'`, `'Mammalia'`, `'Reptilia'`, `'Insecta'`,
  /// `'Plantae'`). Útil para detección de subcategorías cuando los
  /// `ancestros` no vienen poblados — el endpoint `/taxa` de
  /// búsqueda a veces los omite.
  final String? iconicoTaxon;
  final List<String> ancestros;

  ResultadoTaxonInaturalist({
    required this.id,
    required this.nombreCientifico,
    this.nombreComun,
    this.rangoTaxonomico,
    this.urlFoto,
    this.atribucionFoto,
    this.reino,
    this.iconicoTaxon,
    this.ancestros = const [],
  });

  /// Categoría aproximada del cuaderno: 'planta' | 'insecto' | 'ave' |
  /// 'mamifero' | 'reptil' | 'anfibio' | 'animal' | null. La detección
  /// específica (ave / insecto / mamifero / reptil / anfibio) precede a
  /// la genérica 'animal' — un mirlo es Animalia pero también Aves, y
  /// queremos que caiga en su categoría específica para que la app le
  /// ofrezca los atributos correctos.
  String? get categoriaInferida {
    final r = reino;
    if (r == null) return null;
    if (r == 'Plantae' || r == 'Fungi') return 'planta';
    if (r == 'Animalia') {
      // Detección por iconic_taxon_name (campo de primer nivel de
      // iNaturalist, siempre presente) ANTES de mirar ancestros, que
      // pueden no venir poblados desde /taxa.
      if (iconicoTaxon == 'Aves') return 'ave';
      if (iconicoTaxon == 'Mammalia') return 'mamifero';
      if (iconicoTaxon == 'Reptilia') return 'reptil';
      if (iconicoTaxon == 'Amphibia') return 'anfibio';
      if (iconicoTaxon == 'Actinopterygii' || iconicoTaxon == 'Chondrichthyes') {
        return 'pez';
      }
      if (iconicoTaxon == 'Insecta' || iconicoTaxon == 'Arachnida') {
        return 'insecto';
      }
      const filosArtropodos = {'Arthropoda'};
      for (final ancestro in ancestros) {
        if (filosArtropodos.contains(ancestro)) return 'insecto';
        if (ancestro == 'Aves') return 'ave';
        if (ancestro == 'Mammalia') return 'mamifero';
        if (ancestro == 'Reptilia') return 'reptil';
        if (ancestro == 'Amphibia') return 'anfibio';
        if (ancestro == 'Actinopterygii' || ancestro == 'Chondrichthyes') {
          return 'pez';
        }
      }
      return 'animal';
    }
    return null;
  }
}

/// Busca taxones por nombre común o científico.
///
/// [rango] opcional: 'species', 'genus', 'family', etc.
/// [locale] el idioma para nombres comunes (ej. 'es').
Future<List<ResultadoTaxonInaturalist>> buscarTaxones(
  String consulta, {
  String? rango,
  int limite = 10,
  String locale = 'es',
}) async {
  final consultaLimpia = consulta.trim();
  if (consultaLimpia.isEmpty) return const [];

  final parametros = <String, String>{
    'q': consultaLimpia,
    'per_page': limite.clamp(1, 30).toString(),
    'locale': locale,
  };
  if (rango != null && rango.isNotEmpty) {
    parametros['rank'] = rango;
  }

  final uri = Uri.parse('$_baseInaturalist/taxa').replace(queryParameters: parametros);
  final respuesta = await http.get(uri, headers: _cabecerasInaturalist);
  if (respuesta.statusCode != 200) {
    throw Exception(SoleraL10n.tf('nat.ajus_servicio_devolvio', {'servicio': 'iNaturalist', 'codigo': '${respuesta.statusCode}'}));
  }
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];

  return resultados.cast<Map<String, dynamic>>().map((mapa) {
    final fotoDefecto = mapa['default_photo'] as Map<String, dynamic>?;
    final ancestros = (mapa['ancestors'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((a) => (a['name'] as String?) ?? '')
            .where((nombre) => nombre.isNotEmpty)
            .toList() ??
        const <String>[];
    return ResultadoTaxonInaturalist(
      id: (mapa['id'] as num).toInt(),
      nombreCientifico: (mapa['name'] as String?) ?? '',
      nombreComun: mapa['preferred_common_name'] as String?,
      rangoTaxonomico: mapa['rank'] as String?,
      urlFoto: fotoPorDefectoAbierta(fotoDefecto)?.url,
      atribucionFoto: fotoPorDefectoAbierta(fotoDefecto)?.atribucion,
      reino: _inferirReinoDesdeAncestros(mapa) ?? mapa['iconic_taxon_name'] as String?,
      iconicoTaxon: mapa['iconic_taxon_name'] as String?,
      ancestros: ancestros,
    );
  }).toList();
}

/// URL (talla media) y atribución de la `default_photo` de un taxón, o
/// null si su licencia no es CC0, CC BY ni CC BY-SA (NC, ND o «todos los
/// derechos reservados» no se enseñan nunca).
({String url, String atribucion})? fotoPorDefectoAbierta(Map<String, dynamic>? foto) {
  if (foto == null) return null;
  final licencia = licenciaAbiertaDesdeCodigo(foto['license_code'] as String?);
  if (licencia == null) return null;
  final url = foto['medium_url'] as String? ?? foto['square_url'] as String?;
  if (url == null) return null;
  final autor = (foto['attribution_name'] as String?)?.trim();
  final atribucion = autor == null || autor.isEmpty
      ? (foto['attribution'] as String?) ?? 'iNaturalist · ${nombreLicencia(licencia)}'
      : licencia == LicenciaAbierta.cc0
          ? '$autor · ${nombreLicencia(licencia)}'
          : '© $autor · ${nombreLicencia(licencia)}';
  return (url: url, atribucion: atribucion);
}

String? _inferirReinoDesdeAncestros(Map<String, dynamic> mapa) {
  final iconico = mapa['iconic_taxon_name'] as String?;
  if (iconico == null) return null;
  return switch (iconico) {
    'Plantae' || 'Fungi' => 'Plantae',
    'Animalia' || 'Mammalia' || 'Aves' || 'Reptilia' || 'Amphibia' || 'Actinopterygii' || 'Mollusca' => 'Animalia',
    'Insecta' || 'Arachnida' => 'Animalia',
    _ => iconico,
  };
}

/// Caché en memoria de la foto de referencia por nombre científico.
final Map<String, Future<ResultadoTaxonInaturalist?>> _cacheReferenciaPorNombre = {};

/// Taxón más representativo para [nombreCientifico], con su foto por defecto
/// solo si es de licencia abierta (y su atribución). Cachea los resultados
/// (también los nulos) para no martillear iNaturalist.
Future<ResultadoTaxonInaturalist?> taxonDeReferencia(String nombreCientifico) {
  final clave = nombreCientifico.trim().toLowerCase();
  if (clave.isEmpty) return Future.value(null);
  return _cacheReferenciaPorNombre.putIfAbsent(clave, () async {
    try {
      final resultados = await buscarTaxones(nombreCientifico, limite: 1);
      return resultados.isEmpty ? null : resultados.first;
    } catch (_) {
      return null;
    }
  });
}

/// URL de la miniatura de licencia abierta para [nombreCientifico], o null.
Future<String?> miniaturaPorNombreCientifico(String nombreCientifico) async =>
    (await taxonDeReferencia(nombreCientifico))?.urlFoto;

/// Detalle de un taxon por id (devuelve la cadena ancestral completa).
Future<ResultadoTaxonInaturalist?> obtenerTaxon(int id, {String locale = 'es'}) async {
  final uri = Uri.parse('$_baseInaturalist/taxa/$id').replace(queryParameters: {'locale': locale});
  final respuesta = await http.get(uri, headers: _cabecerasInaturalist);
  if (respuesta.statusCode != 200) return null;
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final resultados = (cuerpo['results'] as List?) ?? const [];
  if (resultados.isEmpty) return null;
  final mapa = resultados.first as Map<String, dynamic>;
  final ancestros = (mapa['ancestors'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map((a) => (a['name'] as String?) ?? '')
          .where((nombre) => nombre.isNotEmpty)
          .toList() ??
      const <String>[];
  final fotoDefecto = mapa['default_photo'] as Map<String, dynamic>?;
  return ResultadoTaxonInaturalist(
    id: (mapa['id'] as num).toInt(),
    nombreCientifico: (mapa['name'] as String?) ?? '',
    nombreComun: mapa['preferred_common_name'] as String?,
    rangoTaxonomico: mapa['rank'] as String?,
    urlFoto: fotoPorDefectoAbierta(fotoDefecto)?.url,
    atribucionFoto: fotoPorDefectoAbierta(fotoDefecto)?.atribucion,
    reino: _inferirReinoDesdeAncestros(mapa),
    iconicoTaxon: mapa['iconic_taxon_name'] as String?,
    ancestros: ancestros,
  );
}
