# Checklist publicación Play Store — Fósiles

Estado al 2026-05-19, app versión 1.0.13+14.

## Hecho ya

- Icono de la aplicación con foreground y background adaptativo (`assets/icon/icon.png` 1024×1024).
- Splash nativo configurado (`flutter_native_splash`).
- Target SDK 35, compile SDK 36 (al día con los requisitos de Play Store 2026).
- APK release generable (firmada todavía con debug keystore — ver bloque "Firma").
- Política de privacidad redactada → `docs/play-store/politica-privacidad.md`.
- Ficha de Play Store redactada → `docs/play-store/ficha-play-store.md`.

## Pendiente — decisión

- [ ] **Dominio**: registrar `gailuxare.<tld>` (o el que finalmente se elija) y decidir el TLD.
- [ ] **applicationId** definitivo: candidatos `com.gailuxare.fosiles` o `com.gailuxare.naturaleza.fosiles`. Es **inmutable** una vez publicado.
- [ ] **Developer name** en Play Console (recomendación previa: "Josu Irurtzun" para esta primera entrega).
- [ ] **Email de contacto público** del desarrollador.
- [ ] **URL donde alojar la política de privacidad** (la URL tiene que servir un HTML accesible públicamente; no vale un PDF en Drive).

## Pendiente — cambios en el código (orden sugerido)

### Limpieza del AndroidManifest

Revisar `android/app/src/main/AndroidManifest.xml` y quitar permisos que el código **no** usa, para evitar fricción en la revisión de Play Store:

- [ ] `FOREGROUND_SERVICE` — no se usa ningún servicio en primer plano en `lib/`.
- [ ] `FOREGROUND_SERVICE_LOCATION` — idem; el GPS se usa en primer plano de la actividad mediante `geolocator`, no como servicio.
- [ ] `POST_NOTIFICATIONS` — no hay plugin de notificaciones (ni `flutter_local_notifications` ni similar) en `pubspec.yaml`. Las menciones a "notifications" en el código son iconos de Material UI.
- [ ] Confirmar si `WAKE_LOCK` sigue siendo necesario al grabar tracks largos; si lo es, dejarlo y declararlo así en la ficha. Si no, quitar.

### applicationId y namespace

- [ ] Cambiar `applicationId` de `com.josu.fosiles` al elegido en `android/app/build.gradle:25`.
- [ ] Alinear el `namespace` (`android/app/build.gradle:10`, hoy `com.josu.fosiles.fosiles_flutter`) con el nuevo applicationId.
- [ ] Mover `MainActivity.kt` al paquete correspondiente bajo `android/app/src/main/kotlin/` si el cambio de namespace lo requiere.

### Firma de release

- [ ] Generar keystore de release (guardar contraseña y archivo con backup):

  ```bash
  keytool -genkey -v \
    -keystore ~/keystores/fosiles-release.jks \
    -alias fosiles \
    -keyalg RSA -keysize 2048 -validity 10000
  ```

- [ ] Crear `android/key.properties` (NO subir al repo):

  ```properties
  storePassword=...
  keyPassword=...
  keyAlias=fosiles
  storeFile=/home/josu/keystores/fosiles-release.jks
  ```

- [ ] Añadir `android/key.properties` y `*.jks` al `.gitignore`.
- [ ] Reemplazar el bloque `buildTypes { release { signingConfig = signingConfigs.debug } }` por una configuración real:

  ```gradle
  def keystoreProperties = new Properties()
  def keystorePropertiesFile = rootProject.file('key.properties')
  if (keystorePropertiesFile.exists()) {
      keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
  }

  android {
      signingConfigs {
          release {
              keyAlias = keystoreProperties['keyAlias']
              keyPassword = keystoreProperties['keyPassword']
              storeFile = keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
              storePassword = keystoreProperties['storePassword']
          }
      }
      buildTypes {
          release {
              signingConfig = signingConfigs.release
          }
      }
  }
  ```

- [ ] Activar Play App Signing en Play Console (recomendado): Google guarda la clave maestra y tú firmas con la "upload key". Si pierdes la upload key, Google te permite resetearla; sin Play App Signing, una clave perdida implica perder la app para siempre.
- [ ] Construir el AAB:

  ```bash
  cd apps/fosiles
  flutter build appbundle --release
  ```

  Resultado en `build/app/outputs/bundle/release/app-release.aab`.

## Pendiente — activos visuales

- [ ] Generar icono 512×512 (reescalar `assets/icon/icon.png`).
- [ ] Diseñar gráfico de cabecera 1024×500.
- [ ] Capturar al menos 4 pantallas en móvil real (lista 1.x: inicio, mapa con capa IGME, ficha de hallazgo, medición de estrato).

## Pendiente — Play Console

- [ ] Crear nueva app en Play Console con el applicationId elegido.
- [ ] Rellenar ficha con los textos de `docs/play-store/ficha-play-store.md`.
- [ ] Subir icono, gráfico de cabecera y capturas.
- [ ] Rellenar Data Safety form siguiendo la guía de `docs/play-store/ficha-play-store.md`.
- [ ] Completar el cuestionario de Content Rating (PEGI 3 esperado).
- [ ] Declarar target audience y país de distribución.
- [ ] Subir la URL de política de privacidad (debe servir el HTML público, no un PDF en Drive).
- [ ] Subir el AAB al **Internal Testing track**.
- [ ] Crear lista de testers internos y añadir el correo del geólogo.
- [ ] Esperar revisión inicial (puede tardar entre horas y varios días).
- [ ] Enviar al geólogo el opt-in link de Internal Testing.

## Notas

- El servicio `comunidad` está detrás de un feature flag a `false` (`lib/comunidad/feature_flag_comunidad.dart`). No se envía nada a red. La política y la ficha lo reflejan así. Si más adelante se activa, hay que reeditar política y data safety form **antes** de publicar la versión que lo encienda.
- El chat con IA usa claves de API que el usuario aporta (modelo BYO). El desarrollador no intermedia. La política y la ficha lo reflejan así.
