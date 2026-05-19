# Cuadernos de Campo

Apps de operador para **adulto aficionado** a la geología, paleontología y naturaleza. Cada app es un cuaderno de campo móvil que registra hallazgos georreferenciados con foto, edad, descripción y notas.

## Apps

- **`apps/fosiles/`** — Cuaderno de fósiles y minerales. Cobertura cartográfica IGME nacional (capas GEODE 50, MAGNA 50, Edades 1M, Litologías 1M), guía de identificación, catálogo de yacimientos, asistente IGME contextual, módulo opcional de aportaciones a la comunidad con curaduría profesional.
- **`apps/naturaleza/`** — Cuaderno de naturaleza (avistamientos de fauna, flora y otros elementos del medio). Misma arquitectura base que fósiles, sin asistente geológico.

## Relación con el repo `nuevo-ser/`

Estas apps **dependen de** `packages/nuevo_ser_core` del repo sibling `nuevo-ser/` (vía `path:` relativo en sus `pubspec.yaml`). El paquete `nuevo_ser_core` sigue viviendo allí porque también lo usan las apps Kids (Uno Roto, Las Versiones, El Cuaderno, El Descifrador) y la suite comercial Solera (agro, viticultura, apicultura, arbolado urbano, quesera, aceitera).

**Layout esperado:**

```
~/Projects/games/
├── nuevo-ser/                  ← Kids + Solera + plataforma compartida + wp-plugin
│   ├── apps/
│   │   ├── uno-roto/
│   │   ├── las-versiones/
│   │   ├── el-cuaderno/
│   │   ├── el-descifrador/
│   │   ├── agro/
│   │   └── solera-*/
│   ├── packages/
│   │   ├── nuevo_ser_core/     ← ESTO lo importan fósiles y naturaleza
│   │   ├── nuevo_ser_companion/
│   │   └── nuevo_ser_tutor/
│   └── wp-plugin/nuevo-ser-core/
└── cuadernos-de-campo/         ← ESTE repo
    └── apps/
        ├── fosiles/
        └── naturaleza/
```

Si solo clonas este repo sin `nuevo-ser/` al lado, `flutter pub get` fallará porque no encuentra `../../../nuevo-ser/packages/nuevo_ser_core`. Soluciones:

1. **Clonar nuevo-ser como hermano** (recomendado).
2. Editar la línea `path:` del `pubspec.yaml` de la app afectada para apuntar a una ruta absoluta.
3. Sustituir el `path:` por un `git:` dependency apuntando al repo de nuevo-ser.

## Backend (wp-plugin) del módulo Comunidad de Fósiles

El módulo de "ciencia ciudadana" de Fósiles (aportaciones moderadas) tiene su backend en `wp-plugin/nuevo-ser-core/` del repo `nuevo-ser/`. Cuando se active, este repo solo contiene el cliente Flutter; el wp-plugin se despliega aparte.

Activación del módulo:

1. Configurar `wp-plugin/nuevo-ser-core/` en un WP de producción (ver `nuevo-ser/wp-plugin/nuevo-ser-core/README.md`).
2. Cambiar `kFeatureComunidadHabilitada = true` y `urlBaseComunidad = 'https://tu-dominio.com/wp-json/nuevo-ser/v1/fosiles'` en `apps/fosiles/lib/comunidad/feature_flag_comunidad.dart`.
3. Rebuild y publicar APK.

## Comandos habituales

```bash
# Bootstrap del workspace
dart pub get
dart pub global activate melos    # si no lo tienes ya
melos bootstrap
melos run analyze
melos run test

# Por app
( cd apps/fosiles && flutter run -d linux )
( cd apps/fosiles && flutter build apk --release )
( cd apps/naturaleza && flutter test )
```

```bash
# Flutter no siempre está en PATH:
export PATH="$HOME/flutter/bin:$PATH"

# Build Android requiere Java 17 (forzado en android/gradle.properties).
```

## Convenciones

- **Castellano descriptivo** en variables, clases y archivos (heredado del monorepo nuevo-ser). Términos técnicos (widget, builder…) en original.
- **Tono adulto, sin emojis**. Estas apps no son Kids; hablan a adulto aficionado o profesional.
- **Privacidad estructural**: las coordenadas precisas de un hallazgo viven en sqflite local. Lo que sale del dispositivo es siempre por acción explícita del usuario (exportar `.fos-card`, aportar a la comunidad).

## Historia

Estas apps se extrajeron de `nuevo-ser/` el 2026-05-19 conservando su historia git completa mediante `git subtree split`. El `git blame` debería trazar correctamente todos los commits anteriores a esa fecha aunque vivan ahora en este repo.

## Licencia

(pendiente — ver decisión del operador antes de la primera publicación pública)
