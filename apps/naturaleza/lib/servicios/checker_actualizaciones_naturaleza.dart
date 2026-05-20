import 'package:flutter/foundation.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

/// Config concreta para Naturaleza: vive en el repo
/// `JosuIru/cuadernos-de-campo` (sibling de nuevo-ser/), y sus
/// releases llevan el prefijo `naturaleza-v` (`naturaleza-v1.0.3`).
/// El asset descargable se filtra por contener "naturaleza-" en el
/// nombre, para distinguirlo del APK de Fósiles que también vive
/// en el mismo repo.
const ConfigActualizaciones configActualizacionesNaturaleza =
    ConfigActualizaciones(
  repoOwner: 'JosuIru',
  repoName: 'cuadernos-de-campo',
  prefijoTag: 'naturaleza-v',
  sufijoAsset: 'naturaleza-',
);

/// Estado vivo del checker — la pantalla de inicio lo escucha y
/// muestra el banner cuando hay actualización.
final ValueNotifier<ActualizacionDisponible?> notificadorActualizacion =
    ValueNotifier<ActualizacionDisponible?>(null);

/// Lanza la comprobación en background. No bloquea el arranque: si
/// la red está caída o tarda, la app sigue funcionando. Se llama una
/// vez desde `main()`.
Future<void> comprobarActualizacionNaturalezaEnBackground() async {
  try {
    final resultado = await comprobarActualizacionDisponible(
      configActualizacionesNaturaleza,
    );
    notificadorActualizacion.value = resultado;
  } catch (_) {
    // Best-effort: si algo falla, el banner simplemente no aparece.
  }
}
