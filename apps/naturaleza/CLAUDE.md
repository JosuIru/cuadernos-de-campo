# Naturaleza — CLAUDE.md

Cerebro persistente del proyecto. Se lee al inicio de cada sesión.

## Encuadre

App **del operador** (Josu), no de la línea Kids. Cuaderno de campo de naturaleza (animales, insectos y plantas) orientado a **adulto aficionado**: anota hallazgos georreferenciados con foto, marca tracks GPS, consulta una guía de identificación.

Vivía en `~/Projects/naturaleza-flutter/`. Se trae al monorepo `nuevo-ser/` para **reutilizar plataforma compartida** (`nuevo_ser_core`: storage cifrado, gestor de perfiles, sync, mapas offline cuando se extraigan al core). Hermana técnica de `apps/fosiles/` — comparten estructura y stack pero su catálogo es vivo en vez de mineral.

## Stack actual

Idéntico a `apps/fosiles/`:
- `flutter_map` ^7.0.2 + `latlong2` ^0.9.1
- `geolocator` 12.0.0 + `permission_handler` ^11.3.1
- `image_picker` ^1.1.2 + `path_provider` ^2.1.4
- `sqflite` ^2.3.3 + `shared_preferences` ^2.3.2

## Estructura

```
lib/
├── datos/                 # base_datos.dart (sqflite), datos_guia, configuracion
├── modelos/               # Hallazgo, Track
├── pantallas/             # lista, mapa, mapas offline, anotar, estadísticas,
│                          # guía, quiz, tracks, ajustes, nuevo
├── servicios/
├── estado/
└── utiles/
```

~6.5k LOC. Más simple que `apps/fosiles/` porque el dominio es más estrecho (sin cronoestratigrafía ni minerales). Soporta también compilar a Linux desktop (carpeta `linux/` presente).

## Convivencia con la línea Kids

Mismas reglas que `apps/fosiles/CLAUDE.md`:
- App de adulto, NO aplica la voz adulta amable de la biblia del cuaderno.
- Quiz y estadísticas son legítimos aquí (los hard limits §2 son del cuaderno, no de esta app).
- Privacidad estructural en el sync (cuando exista): coords precisas locales, metadata al backend.
- No se fusiona con el cuaderno — share intent si el niño necesita identificar algo.

## Catálogos compartibles

`datos_guia.dart` es candidato a moverse a `content/` del monorepo para que:
- El comité científico del cuaderno (B1 pendiente, memoria operador) lo audite y extienda.
- El cuaderno lo consume al construir Misterios contextualizados al lugar y la estación.

Sin contaminar voz: solo datos curados.

## Diferencias notables vs `apps/fosiles/`

- Sin `pantalla_linea_tiempo.dart` (la naturaleza viva no tiene cronoestratigrafía).
- Sin `datos_minerales.dart` ni `yacimientos_curados.dart`.
- Sin `modal_orientacion_estrato.dart` (no aplica strike/dip).
- Soporta target Linux desktop.

## Reglas de interacción

- **No reescribir la voz** para que parezca app Kids. Habla a adultos.
- **Nombres descriptivos en castellano** (regla de monorepo) en código nuevo.

## Comandos habituales

```bash
export PATH="$HOME/flutter/bin:$PATH"
( cd apps/naturaleza && flutter analyze )
( cd apps/naturaleza && flutter test )
( cd apps/naturaleza && flutter run -d linux )
( cd apps/naturaleza && flutter build apk --release )
```

## Plantas: usos con fuente y aviso de consumo (2026-11-10)

Decidido con Josu: fuera las etiquetas sueltas **«Medicinal»** y **«Comestible»** (40 y 17 plantas; sin fuente, y la dedalera salía «tóxica, medicinal»). En su lugar:
- **Uso tradicional según la EMA**: solo lo que dicen las monografías de la Unión del HMPC (Agencia Europea del Medicamento), con la parte de la planta, **precauciones y contraindicaciones delante**, el estado de la monografía y su enlace. **Sin dosis ni preparaciones** (test). Datos en `datos_fuente/usos_tradicionales_ema.csv` → `python3 tool/generar_usos_tradicionales.py` → `lib/datos/usos_tradicionales.dart` (no editar a mano). Leídas el 2026-11-10: 31 especies con monografía; sin monografía, nada (amapola, zarzamora, jara, laurel, escaramujo, orégano, verbena, ruda…). Los resúmenes en castellano son de IA: **pendiente de cotejo por una persona**.
- **Tóxicas y protegidas no enseñan uso** aunque tengan monografía (hiedra, ajenjo, genciana, árnica): `usosTradicionalesDe`. Poleo y borraja enseñan solo el aviso de toxicidad de la EMA.
- **Aviso fijo** en todas las fichas de plantas y setas: la guía no sirve para decidir si algo se come, se bebe o se usa.
- **«Se confunde con»** (`EspecieGuia.confundibles`), sobre todo las peligrosas (hinojo/cicuta, genciana/vedegambre).
- **10 aromáticas silvestres** traídas de Larrea Aromáticas (`content/aromaticas/` del monorepo): lavanda, espliego, tomillo salsero y blanco, salvia española, ajedrea, hisopo, té de roca, genciana y árnica (estas dos, protegidas). Sus rasgos y hábitat tampoco están revisados por una persona botánica.
- Larrea Aromáticas (app profesional que vende lotes) sigue **sin ninguna propiedad**: ahí el riesgo es legal (Reglamento 1924/2006, RD 1907/1996).
Textos nuevos `nat.ficha_*` en `content/solera/traducciones/naturaleza_guia.csv` del monorepo.
