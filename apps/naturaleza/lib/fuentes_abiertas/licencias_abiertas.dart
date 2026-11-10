/// Licencias de foto que la app acepta de fuentes externas (iNaturalist).
///
/// Solo CC0, CC BY y CC BY-SA: permiten el uso comercial con atribución
/// (la app podría tener ingresos en el futuro). **Nunca** NC (no comercial),
/// ND (sin obras derivadas: la app recorta y redimensiona) ni «todos los
/// derechos reservados» (iNaturalist lo devuelve como `license_code: null`).
enum LicenciaAbierta { cc0, ccBy, ccBySa }

/// Licencia aceptada a partir del código de iNaturalist (`cc0`, `cc-by`,
/// `cc-by-sa`…) o de una variante con versión o guiones bajos
/// (`CC-BY-4.0`, `cc_by_sa`). Devuelve null para cualquier otra, también
/// si lleva NC o ND o si no hay código.
LicenciaAbierta? licenciaAbiertaDesdeCodigo(String? codigo) {
  if (codigo == null) return null;
  var normalizado = codigo.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  if (normalizado.isEmpty) return null;
  final partes = normalizado.split('-');
  if (partes.contains('nc') || partes.contains('nd')) return null;
  // Quita la versión final («4.0», «4-0», «3»).
  normalizado = normalizado.replaceFirst(RegExp(r'-\d+([.-]\d+)?$'), '');
  return switch (normalizado) {
    'cc0' || 'cc-zero' => LicenciaAbierta.cc0,
    'cc-by' => LicenciaAbierta.ccBy,
    'cc-by-sa' => LicenciaAbierta.ccBySa,
    _ => null,
  };
}

/// Código canónico para guardar en caché (`cc0`, `cc-by`, `cc-by-sa`).
String codigoLicencia(LicenciaAbierta licencia) => switch (licencia) {
      LicenciaAbierta.cc0 => 'cc0',
      LicenciaAbierta.ccBy => 'cc-by',
      LicenciaAbierta.ccBySa => 'cc-by-sa',
    };

/// Nombre corto para la atribución visible.
String nombreLicencia(LicenciaAbierta licencia) => switch (licencia) {
      LicenciaAbierta.cc0 => 'CC0',
      LicenciaAbierta.ccBy => 'CC BY',
      LicenciaAbierta.ccBySa => 'CC BY-SA',
    };

/// Texto legal de la licencia (versión 4.0, la que enlaza iNaturalist;
/// CC0 solo tiene la 1.0).
String urlLicencia(LicenciaAbierta licencia) => switch (licencia) {
      LicenciaAbierta.cc0 => 'https://creativecommons.org/publicdomain/zero/1.0/',
      LicenciaAbierta.ccBy => 'https://creativecommons.org/licenses/by/4.0/',
      LicenciaAbierta.ccBySa => 'https://creativecommons.org/licenses/by-sa/4.0/',
    };

/// Valor del parámetro `photo_license` de iNaturalist con las licencias
/// aceptadas.
const String filtroLicenciasInaturalist = 'cc0,cc-by,cc-by-sa';

/// Licencias de registro aceptadas en GBIF (parámetro `license`): sin
/// CC BY-NC, por la misma razón que las fotos.
const List<String> licenciasRegistrosGbif = ['CC0_1_0', 'CC_BY_4_0'];
