import 'package:flutter/foundation.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

/// Config concreta para Fósiles: por motivos históricos las APKs
/// de Fósiles se publican en el repo `JosuIru/nuevo-ser` con tag
/// fechado `apks-YYYY-MM-DD` y el APK lleva `fosiles-` en el nombre.
///
/// El checker requeriría un prefijo de tag estable para distinguir
/// releases nuevas de Fósiles. Para el siguiente release de Fósiles
/// migraremos a `fosiles-vX.Y.Z` (alineado con el patrón de
/// cuadernos-de-campo/naturaleza) y este config quedará en el sitio.
/// Hasta entonces, el filtro `prefijoTag` queda permisivo y la
/// filtración real recae sobre el nombre del asset descargable.
const ConfigActualizaciones configActualizacionesFosiles =
    ConfigActualizaciones(
  repoOwner: 'JosuIru',
  repoName: 'nuevo-ser',
  // TODO: cuando se cree el tag `fosiles-v1.0.X`, cambiar a
  //       prefijoTag: 'fosiles-v',
  prefijoTag: 'fosiles-v',
  sufijoAsset: 'fosiles-',
);

final ValueNotifier<ActualizacionDisponible?>
    notificadorActualizacionFosiles =
    ValueNotifier<ActualizacionDisponible?>(null);

Future<void> comprobarActualizacionFosilesEnBackground() async {
  try {
    final resultado = await comprobarActualizacionDisponible(
      configActualizacionesFosiles,
    );
    notificadorActualizacionFosiles.value = resultado;
  } catch (_) {
    // best-effort
  }
}
