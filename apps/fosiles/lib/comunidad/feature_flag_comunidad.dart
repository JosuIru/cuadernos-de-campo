/// Feature flag para el sistema de aportaciones a la comunidad (ciencia
/// ciudadana con curaduría experta).
///
/// **Cuando ponerlo a `true`**: NO antes de tener:
///   1. Un geólogo o paleontólogo profesional dispuesto a curar
///   2. El backend `wp-plugin/nuevo-ser-core` extendido con los
///      endpoints `/nuevo-ser/v1/fosiles/*` (ver plan
///      `~/.claude/plans/magical-tumbling-thunder.md`)
///   3. Política de privacidad + T&Cs revisados
///   4. Configuración de `urlBaseComunidad` apuntando a un servidor real
///
/// Al estar a `false`:
///   - Toda la UI relativa a "compartir con la comunidad" queda oculta
///   - Ningún código HTTP a backend se ejecuta
///   - Tree-shaking de Flutter elimina las ramas inalcanzables del APK
///
/// El módulo `lib/comunidad/` queda compilado y verificado en cada
/// `flutter analyze` para que no se oxide mientras espera ser activado.
const bool kFeatureComunidadHabilitada = false;

/// URL base del backend cuando el flag esté activo. Placeholder hasta
/// que haya instancia real. Cambiar también en este sitio al activar.
const String urlBaseComunidad =
    'https://placeholder-pendiente-de-activar.example.com/nuevo-ser/v1/fosiles';
