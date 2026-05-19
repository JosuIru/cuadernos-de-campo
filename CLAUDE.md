# Fósiles — CLAUDE.md

Cerebro persistente del proyecto. Se lee al inicio de cada sesión.

## Encuadre

App **del operador** (Josu), no de la línea Kids. Cuaderno de campo de fósiles orientado a **adulto aficionado**: anota hallazgos georreferenciados con foto, edad, formación, strike/dip de la capa, marca tracks GPS, consulta yacimientos curados y una guía de identificación. Cobertura cartográfica IGME nacional.

Vivía en `~/Projects/fosiles-flutter/`. Se trae al monorepo `nuevo-ser/` para **reutilizar plataforma compartida** (`nuevo_ser_core`: storage cifrado, gestor de perfiles, sync, mapas offline cuando se extraigan al core). Mantiene su voz y su audiencia — no se mezcla con las apps Kids.

## Stack actual

- `flutter_map` ^7.0.2 + `latlong2` ^0.9.1
- `geolocator` 12.0.0 + `permission_handler` ^11.3.1
- `image_picker` ^1.1.2 + `path_provider` ^2.1.4
- `sqflite` ^2.3.3 (no Isar — preexistente)
- `shared_preferences` ^2.3.2

Sin Flame, sin Riverpod, sin Isar.

## Estructura

```
lib/
├── datos/                 # base_datos.dart (sqflite), datos_guia, datos_minerales,
│                          # cronoestratigrafia, yacimientos_curados, configuracion
├── modelos/               # Hallazgo (fosil/mineral), Track
├── pantallas/             # lista, mapa, mapas offline, anotar, estadísticas,
│                          # guía, línea de tiempo, quiz, tracks, ajustes,
│                          # nuevo, modal orientación estrato
├── servicios/
├── estado/
└── utiles/
```

~9.3k LOC. APK release estable (v1.0).

## Convivencia con la línea Kids

- **NO aplica** la voz adulta amable de la biblia del cuaderno (esto es app de adulto, no de niño).
- **NO aplican** los hard limits §2 (sin XP/quiz/estadísticas) — esta app **sí** tiene `pantalla_quiz.dart` y `pantalla_estadisticas.dart` legítimamente.
- **SÍ** se respeta privacidad estructural cuando se sincroniza al backend: las coords precisas se quedan en local (sqflite); al backend va metadata + la zona NUTS-3, igual que el cuaderno.
- **NO** se fusiona con el cuaderno. Si el cuaderno necesita identificar un fósil, lanza un share intent al adulto que tiene esta app instalada — no replica la guía dentro.

## Catálogos compartibles

`datos_guia.dart`, `datos_minerales.dart`, `cronoestratigrafia.dart` y `yacimientos_curados.dart` son contenido curado por el operador con valor pedagógico. **Candidatos a moverse a `content/` del monorepo** para que el cuaderno los lea al construir Misterios y el comité científico (B1 del cuaderno) los pueda revisar/extender. Sin contaminar voz: solo datos.

## Reglas de interacción

- **No reescribir la voz** ni la UX para que parezca app Kids. Esta app habla a adultos.
- **Nombres descriptivos en castellano** (regla de monorepo) en código nuevo.
- Tests existentes son mínimos. No exigir cobertura como en Kids — código preexistente del operador.

## Comandos habituales

```bash
export PATH="$HOME/flutter/bin:$PATH"
( cd apps/fosiles && flutter analyze )
( cd apps/fosiles && flutter test )
( cd apps/fosiles && flutter run -d linux )
( cd apps/fosiles && flutter build apk --release )
```
