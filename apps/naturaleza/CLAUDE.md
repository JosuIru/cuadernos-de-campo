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

## «¿Quién canta?»: identificar fauna por el sonido (2026-11-10)

Portado de **Laboratorio de Bolsillo** (`~/Projects/app-kamara-sonar`, rama `main`, `instruments/wildlife-sounds/`; ese repo no se toca). Decidido:
- **Inferencia con `tflite_flutter` 0.12.1** (repo de TensorFlow, LiteRT 1.4.0 en Android, FFI). Se descartó `flutter_litert` (más activo, pero descarga AAR durante el build y mete también LiteRT Next en el APK). En Linux escritorio `tflite_flutter` necesita `blobs/libtensorflowlite_c-linux.so` junto al ejecutable: sin él, la pantalla dice que no puede cargar el modelo (solo se publica Android). Micrófono con `record` (PCM 16 bits a 48 kHz, o 44,1 kHz si no; sin AGC, eco ni supresión de ruido) y reproducción del clip con `audioplayers`.
- **El modelo no va en el APK**: Perch 2.0 (© Google, Apache 2.0) recortado a Europa, release pública `modelo-fauna-europa-1` de `JosuIru/laboratorio-de-bolsillo` (`perch_europe_fp16.tflite` 37 MB + `fauna-manifest.json` + `fauna-occurrence-europa-1.json`). Se descarga una vez tras confirmar (tamaño exacto del manifiesto), con progreso y cancelación, a `documentos/modelo_fauna/`; el SHA-256 se calcula mientras baja y se compara con el manifiesto (y el tamaño). El manifiesto se escribe el último. Si cambia el modelo: otro tag y `urlBaseReleaseModeloFauna` en `lib/servicios/almacen_modelo_fauna.dart`.
- **Lógica pura en `lib/sonido/`** (portada con sus tests en `test/sonido/`): remuestreo sinc-Blackman con antialias a 32 kHz, ventanas de 5 s con solape 2,5 s (sin solape si el análisis pasa de 1,5 s), top 5, umbral «posible» 7 / «probable» 10 y margen relativo 3 respecto a la primera especie, filtro por lugar y época (celdas de 2° de GBIF; «Solo especies de mi zona» excluye, si no −6; fuera de temporada −2), voz humana (una clase `isHumanVoice` entre las 3 primeras con ≥ 4: el trozo no se identifica, no se guarda y no entra en ningún clip). Inferencia y remuestreo en un isolate propio (`lib/servicios/clasificador_fauna.dart`).
- **Integración**: botón «¿Quién canta? Identificar por el sonido» en la tarjeta de identificación del alta de hallazgo (junto a la IA por foto) y atajo en Inicio (sin pestaña nueva). Al elegir una especie (del último trozo o de la lista de la sesión, que guarda en memoria el mejor clip de cada una) se rellena el alta: especie, nombre común, categoría (la de la guía si la especie está; si no, el grupo del manifiesto), evidencia `sonido`, hora en que se oyó y **clip WAV** (16 bits, 32 kHz, 5-10 s: el trozo y la parte nueva del anterior si era contiguo y limpio) en `documentos/audios/`. La ubicación la pone el alta como siempre (GPS si se permite); el filtro usa solo una ubicación redondeada a 0,01° que no se guarda.
- **BD v4**: columna `hallazgos.ruta_audio` (aditiva, nullable; `toMap` solo la incluye si hay audio). `atributos['identificacion_sonido']` guarda modelo, puntuación, nivel y si había filtro; es la única clave de atributos que no depende de la categoría. El detalle del hallazgo reproduce el clip y, si el nombre científico está en la guía, enlaza a su ficha. Copia de seguridad y exportación ZIP llevan `audios/`.
- **Permiso RECORD_AUDIO** pedido al empezar a escuchar; el micrófono se para al salir de la pantalla o al pasar la app a segundo plano (`paused`/`hidden`).
- Avisos: orientativo; validación del original **6 de 7** con grabaciones limpias. Ayuda, créditos y licencias (Perch/Google Apache 2.0, GBIF, AudioSet/FSD50K CC BY) en el botón de ayuda de la propia pantalla, y un paso en «Cómo usar» de Inicio.
- Textos `nat.son_*` en `content/solera/traducciones/naturaleza_sonido.csv` del monorepo. Euskera, catalán y gallego escritos por IA: **pendientes de revisión nativa**.
- **Probado en el emulador** (Android 16 x86_64, prueba de integración temporal, no commiteada): descarga real de la release con SHA-256 correcto, carga con LiteRT 1.4 sin problemas de operadores, 1226 puntuaciones y log-mel 500×128; un silbido sintético da «Music». Tiempos en el emulador: remuestreo 85-230 ms, modelo 12 s el primer trozo y 2,3 s después (con eso ya no solapa). **Falta un móvil real**: micrófono, tiempos reales y aciertos con cantos de verdad.
- El delegado GPU de LiteRT se excluye del APK (`packaging.jniLibs.excludes` en `android/app/build.gradle`): solo se usa la CPU.

## «¿Quién canta?» bloque A: dónde está, lo último oído, calidad y tus sonidos (2026-11-10)

Cuatro funciones sobre la pantalla de escucha. Lógica pura en `lib/sonido/` con tests en `test/sonido/`; estado de pantalla en `lib/servicios/controlador_*.dart`; tarjetas en `lib/pantallas/widgets/`.
- **¿Dónde está? (triangulación)** — `triangulacion_rumbos.dart`. «Viene de aquí» guarda posición GPS (con su precisión), rumbo medio del último segundo de la brújula y lo que dice el sensor de su precisión. Cada toma es una **cuña** (rumbo ± margen, 10° por defecto y elegible 5/10/15/20°; vértice retrasado `precisión / sen(margen)` para cubrir el error del GPS; alcance 1,5 km); la zona es la intersección convexa (Sutherland-Hodgman en plano local equirrectangular). Avisos: falta toma, tomas juntas (< 15 m o < suma de errores GPS), casi paralelas (cruce < 15°), se cruzan a la espalda, sin zona común, tomas del barrido. Mapa pequeño con líneas de rumbo, bordes del margen y zona (`MapaZonaAnimal`, sin arrastre porque va dentro de una lista). Al anotar, `atributos['zona_animal']` = `{centro, contorno [[lat,lng],…], area_m2, avisos, tomas[…], rumbo_verdadero, declinacion}` **aparte de la posición del hallazgo** (que sigue siendo la de la persona); sin migración (atributo «de cualquier categoría», como `identificacion_sonido`). El detalle del hallazgo la enseña con su mapa y el mapa principal dibuja las zonas.
  - **Brújula**: `flutter_compass` 0.8.1 (ya estaba en el pubspec; vector de rotación en Android). Da norte **magnético**; la **declinación** la calcula Android (`GeomagneticField`, modelo WMM) por el canal `naturaleza/declinacion_magnetica` de `MainActivity.kt`. Sin canal (Linux), el rumbo se queda magnético y la tarjeta lo dice (en la península son 1-2°). Si el sensor dice precisión baja (45°), aviso de calibrar (ocho).
  - **Barrido** (`barrido_rumbo.dart`): con la escucha en marcha, la persona gira con el móvil pegado al pecho; se apunta el nivel de la banda 1-8 kHz por tramas de 0,1 s frente al rumbo, sectores de 10°, suavizado 1-2-1; se propone el máximo si se ha cubierto ≥ 180° y destaca ≥ 3 dB sobre la mediana. Toma **orientativa** con margen mínimo de 20°. Se usa energía y no la puntuación del modelo (un valor cada 2,5-5 s no sirve para una vuelta).
- **Lo último oído (10 s)** — `bufer_ultimos_segundos.dart`. Búfer circular a la frecuencia del micro dentro de `EscuchaMicrofonoFauna` (15 s: 10 de clip + 5 de margen para lo aún no analizado), solo mientras la pantalla escucha (se vacía al parar). Del búfer **solo sale audio ya analizado y sin voz humana** (`RegistroTramosAnalizados`: tramos limpios menos los trozos con voz; lo aún no analizado no entra; se toleran huecos de ≤ 0,1 s entre trozos sin solape, que en el emulador eran de 56 ms). En la hoja de la especie, interruptor «Guardar lo último oído (N s)» si es más largo que el clip del trozo; el WAV va a la frecuencia del micro (48 kHz) y `identificacion_sonido.clip_ultimo_oido = true`.
- **Aviso de calidad** — `calidad_audio.dart`. Biquads (RBJ) sobre el audio en bruto, tramas de 0,1 s, evaluación de las últimas 3 s cada 0,5 s. Umbrales **orientativos, sin medir en campo**: saturación > 0,1 % de muestras ≥ 0,98; viento ≥ 60 % de la energía < 150 Hz y a rachas (variación ≥ 0,35); tráfico ≥ 80 % < 1 kHz, estable (≤ 0,25) y esa banda ≥ −50 dBFS; débil < −65 dBFS. Tests con señales sintéticas.
- **Tus sonidos** — `sonidos_propios.dart`, portado del Laboratorio (`customSounds.ts`, commits 1c73831 y 96a4eb4): salida `embedding` [1,1536] de Perch (ahora la devuelve `ClasificadorFauna`), coseno, media de los 2 ejemplos más parecidos, umbral 0,5 (estricta 0,6, sensible 0,4), mínimo 3 y máximo 10 ejemplos, sonido de **fondo** que descarta. Ejemplos = el último trozo limpio («Añadir lo último oído»); nunca un trozo con voz. Solo cuentan los ejemplos de la misma versión del modelo. **BD v5**: tablas `sonidos_propios` y `ejemplos_sonido_propio` (embedding float32 LE en BLOB, nunca audio), migración aditiva con test; van en la copia de seguridad con la BD. Las coincidencias salen encima de «Qué se oye»; no crean hallazgos. Sin exportar/importar JSONL (el Laboratorio sí lo tiene).
- **Pantalla encendida** mientras se escucha: `wakelock_plus` **1.3.3** (las 1.4-1.7 chocan con `package_info_plus ^8` de `nuevo_ser_core` y las 1.8+ piden Dart 3.12), interruptor guardado en preferencias (activo por defecto).
- Textos `nat.son_*` nuevos en `naturaleza_sonido.csv` del monorepo; eu/ca/gl escritos por IA, pendientes de revisión nativa.
- **Probado en el emulador** (Android 16, APK release): descarga del modelo, embedding real (un sonido propio con 3 ejemplos de silencio coincide a 1,00), aviso de señal débil (el micro del emulador no da sonido), wakelock activo (`dumpsys power`), brújula y GPS simulados (`adb emu sensor set magnetic-field`, `adb emu geo fix`): declinación aplicada (28,5° magnéticos → 30° verdaderos en 43° N 2° O), zona correcta con dos tomas, avisos de tomas juntas y a la espalda cuando el GPS no se había movido, barrido con aviso de poca vuelta; «Guardar lo último oído» ofrecido y hallazgo guardado con ese clip (con 10 s de búfer salían 6 s limpios: de ahí el margen de 5 s). **Falta un móvil real**: brújula de verdad (precisión, interferencias), barrido con un animal y umbrales de calidad con viento y tráfico reales.
