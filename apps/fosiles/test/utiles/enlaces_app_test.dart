// «Compartir la app» enlaza la página de la release de esta app en el
// repositorio, no la lista mezclada de releases ni la web de la Colección.

import 'package:flutter_test/flutter_test.dart';
import 'package:fosiles_flutter/servicios/checker_actualizaciones_fosiles.dart';
import 'package:fosiles_flutter/utiles/enlaces_app.dart';

void main() {
  const prefijo = 'fosiles-v';
  const urlReleases =
      'https://github.com/JosuIru/cuadernos-de-campo/releases/tag/';

  test('el prefijo es el del comprobador de actualizaciones', () {
    expect(configActualizacionesFosiles.prefijoTag, prefijo);
  });

  test('sin versión más nueva conocida, la release de la versión instalada',
      () {
    expect(urlReleaseApp(prefijoTag: prefijo, versionInstalada: '1.0.17'),
        '${urlReleases}fosiles-v1.0.17');
  });

  test('con versión más nueva conocida, la release de esa versión', () {
    expect(
        urlReleaseApp(
            prefijoTag: prefijo,
            versionInstalada: '1.0.17',
            versionMasNueva: '1.0.19'),
        '${urlReleases}fosiles-v1.0.19');
  });

  test('la parte de compilación no va en el tag', () {
    expect(urlReleaseApp(prefijoTag: prefijo, versionInstalada: '1.0.17+18'),
        '${urlReleases}fosiles-v1.0.17');
    expect(
        urlReleaseApp(
            prefijoTag: prefijo,
            versionInstalada: '1.0.17+18',
            versionMasNueva: ' 1.0.20+21 '),
        '${urlReleases}fosiles-v1.0.20');
  });

  test('una versión más nueva vacía no cuenta', () {
    expect(
        urlReleaseApp(
            prefijoTag: prefijo,
            versionInstalada: '1.0.17',
            versionMasNueva: ''),
        '${urlReleases}fosiles-v1.0.17');
  });

  test('el User-Agent lleva la web del repositorio y ningún correo', () {
    expect(agenteUsuarioFosiles,
        contains('https://github.com/JosuIru/cuadernos-de-campo'));
    expect(agenteUsuarioFosiles.contains('@'), isFalse);
  });
}
