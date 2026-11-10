import 'package:package_info_plus/package_info_plus.dart';

import '../servicios/checker_actualizaciones_naturaleza.dart';

/// Repositorio público de la app: código y releases (las APK de
/// Naturaleza y de Fósiles conviven en él, cada una con su prefijo de tag).
const String urlRepositorioApp =
    'https://github.com/JosuIru/cuadernos-de-campo';

/// User-Agent de la app para las APIs abiertas (GBIF, iNaturalist,
/// Overpass, Wikipedia): nombre y web, sin correo personal (GBIF pide una
/// URL o un correo para poder avisar).
const String agenteUsuarioNaturaleza =
    'Naturaleza/1.0 (cuaderno de campo de la Coleccion Nuevo Ser; $urlRepositorioApp)';

/// Página de la release de la app que se comparte: la de la versión más
/// nueva que conozca el comprobador de actualizaciones o, si no conoce
/// ninguna, la de la versión instalada (que siempre existe como release).
/// La parte de compilación (`+18`) no va en el tag.
String urlReleaseApp({
  required String prefijoTag,
  required String versionInstalada,
  String? versionMasNueva,
}) {
  final versionConocida = versionMasNueva?.trim() ?? '';
  final version =
      versionConocida.isNotEmpty ? versionConocida : versionInstalada.trim();
  final finCompilacion = version.indexOf('+');
  final versionSinCompilacion =
      finCompilacion < 0 ? version : version.substring(0, finCompilacion);
  return '$urlRepositorioApp/releases/tag/$prefijoTag$versionSinCompilacion';
}

/// [urlReleaseApp] de Naturaleza con la versión instalada y lo que sepa
/// el comprobador de actualizaciones.
Future<String> urlReleaseNaturaleza() async {
  final informacionPaquete = await PackageInfo.fromPlatform();
  return urlReleaseApp(
    prefijoTag: configActualizacionesNaturaleza.prefijoTag,
    versionInstalada: informacionPaquete.version,
    versionMasNueva: notificadorActualizacion.value?.versionDisponible,
  );
}
