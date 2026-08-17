import 'package:flutter/foundation.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

/// Config concreta para Fósiles. Desde `fosiles-v1.0.14` las APKs se
/// publican en este repo (`JosuIru/cuadernos-de-campo`) con tag
/// `fosiles-vX.Y.Z` y asset `fosiles-vX.Y.Z.apk`, el mismo patrón que
/// naturaleza. Los releases antiguos con tag fechado `apks-YYYY-MM-DD`
/// del repo `JosuIru/nuevo-ser` quedan fuera del filtro.
///
/// `sufijoAsset` se compara sensible a mayúsculas contra el nombre del
/// asset, así que el APK del release debe subirse en minúsculas.
const ConfigActualizaciones configActualizacionesFosiles =
    ConfigActualizaciones(
  repoOwner: 'JosuIru',
  repoName: 'cuadernos-de-campo',
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
