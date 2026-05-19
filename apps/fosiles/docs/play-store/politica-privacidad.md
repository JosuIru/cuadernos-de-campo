# Política de privacidad — Fósiles (Cuaderno de Campo)

**Última actualización:** 2026-05-19
**Versión de la aplicación cubierta:** 1.0.14 y posteriores
**Versión de esta política:** 2.0

> Documento sujeto a revisión legal antes de publicación pública. Sustituir `[NOMBRE_RESPONSABLE]`, `[NIF_O_DNI]`, `[DIRECCIÓN_POSTAL]`, `[EMAIL_CONTACTO]`, `[URL_PÚBLICA_DE_ESTA_PÁGINA]` y `[URL_BACKEND_COMUNIDAD]` por los valores definitivos. La URL pública tiene que servir esta política accesiblemente desde el dominio registrado y figurar en la ficha de Google Play.

## 1. Responsable del tratamiento

| | |
|---|---|
| **Responsable** | [NOMBRE_RESPONSABLE] |
| **Identificación fiscal** | [NIF_O_DNI] |
| **Domicilio** | [DIRECCIÓN_POSTAL] |
| **Correo electrónico de contacto** | [EMAIL_CONTACTO] |
| **Delegado de Protección de Datos (DPO)** | No designado. La aplicación no realiza tratamientos a gran escala de datos especialmente protegidos (RGPD art. 37) y queda fuera de los supuestos que obligan a designar DPO. |

## 2. Resumen en una frase

Fósiles es un cuaderno de campo para aficionados a la paleontología y la geología. Por defecto, **todos tus hallazgos, fotos, ubicaciones GPS y notas se guardan únicamente en tu dispositivo**. No hay analítica, ni publicidad, ni envío automático de datos a servidor propio del desarrollador. Solo se produce comunicación externa cuando tú usas funciones que la requieren explícitamente (mapa, asistente IA opcional, módulo "Comunidad" si lo activas).

## 3. Datos que la aplicación procesa

### 3.1 Datos almacenados exclusivamente en tu dispositivo

Estos datos viven en la base de datos local (SQLite) y en preferencias internas del sistema operativo de tu teléfono. **No salen del dispositivo** salvo que tú decidas exportarlos o compartirlos manualmente (ver §5):

- Hallazgos (fósiles y minerales) con su ubicación GPS precisa, fecha, fotografía, especie declarada, edad geológica, formación, orientación de estrato (strike/dip), notas y certificación criptográfica.
- Tracks GPS de salidas de campo.
- Fotografías tomadas con la cámara o seleccionadas de tu galería para vincularlas a un hallazgo.
- Tu identidad de descubridor (nombre, correo electrónico, organización) si decides rellenarla en Ajustes. Se usa para firmar tus hallazgos exportables.
- Tu clave criptográfica privada Ed25519, generada localmente y almacenada cifrada en el almacén seguro del sistema operativo (Android Keystore).
- Tus claves de API de proveedores de IA, si decides introducirlas, almacenadas cifradas (Android Keystore).
- Preferencias de configuración y mapas descargados para uso sin conexión.

### 3.2 Comunicaciones con servicios externos públicos

La aplicación contacta con los siguientes servicios cuando tú usas la funcionalidad que los requiere. **No se les envían tus datos personales identificables**: se envía la información estrictamente técnica necesaria para que el servicio responda (por ejemplo, las coordenadas de la región del mapa que estás viendo). Como en cualquier petición HTTP, estos servicios verán tu dirección IP, idéntico a abrir su web en un navegador.

| Servicio | Cuándo se contacta | Qué se envía | Tratamiento por el tercero |
|---|---|---|---|
| OpenStreetMap (tiles cartográficos) | Al mostrar el mapa base | Coordenadas del tile solicitado | Servicio público sin fines comerciales. <https://wiki.osmfoundation.org/wiki/Privacy_Policy> |
| IGME (Instituto Geológico y Minero de España) — servicios WMS/WFS | Al mostrar la capa geológica nacional | Coordenadas del área visible | Servicio público español. <https://www.igme.es/aviso-legal/> |
| GEODE (Mapa Geológico Continuo de España) | Al consultar formaciones geológicas | Coordenadas de la consulta | Servicio público IGME (mismo enlace). |
| Servicios de mareas | Al consultar el horario de mareas para una localización costera | Coordenadas de la consulta | Proveedor público de datos oceanográficos. |
| Wikipedia / Wikimedia Commons / iNaturalist | Al mostrar galerías de referencia para identificar especies | Nombre de la especie consultada | <https://foundation.wikimedia.org/wiki/Policy:Privacy_policy> · <https://www.inaturalist.org/pages/privacy> |

### 3.3 Asistente de inteligencia artificial (opcional, bajo control del usuario)

La aplicación incluye un asistente conversacional que **solo funciona si tú introduces tu propia clave de API** de uno de los siguientes proveedores:

- **Anthropic Claude** (`api.anthropic.com`)
- **DeepSeek** (`api.deepseek.com`)

Cuando uses el chat, el contenido de tus mensajes (texto y, si las adjuntas, imágenes) se envía directamente desde tu dispositivo al proveedor que hayas configurado. El desarrollador de esta aplicación **no intermedia, no almacena ni accede** a esos mensajes. El responsable del tratamiento de esos datos a partir de ese momento eres tú (o, según la modalidad de tu contrato con el proveedor, una corresponsabilidad con el proveedor). El tratamiento que cada proveedor realiza se rige por su propia política de privacidad:

- Anthropic — <https://www.anthropic.com/legal/privacy>
- DeepSeek — <https://chat.deepseek.com/downloads/DeepSeek%20Privacy%20Policy.html>

**Transferencia internacional:** Anthropic y DeepSeek pueden procesar tus datos fuera del Espacio Económico Europeo (EEE). Antes de introducir una clave de API debes verificar que el proveedor ofrece garantías adecuadas (cláusulas contractuales tipo de la Comisión Europea, decisiones de adecuación, etc.). La aplicación no realiza esa verificación por ti.

### 3.4 Módulo "Comunidad" (aportaciones moderadas)

La aplicación incluye un módulo que permite **enviar fotos de hallazgos a una comunidad** para que un curador profesional (geólogo o paleontólogo) las revise y, si las aprueba, queden visibles dentro de la propia aplicación asociadas a la formación geológica correspondiente (estilo "Wikipedia").

**Estado actual:** este módulo puede estar activo o inactivo según la versión instalada. Cuando está **inactivo**, ninguna comunicación se produce con el backend de comunidad; las opciones del menú quedan ocultas y este apartado §3.4 no aplica.

Cuando está **activo**, antes de cualquier envío la aplicación te muestra un diálogo explícito que resume qué se va a enviar y exige tu **consentimiento expreso** mediante una casilla de aceptación. Solo entonces se transmiten al backend los siguientes datos:

| Dato | Por qué se envía | Quién lo ve |
|---|---|---|
| Fotografía del hallazgo (reducida a 1600 px lado mayor, JPEG q75) | Es el contenido principal de la aportación | Curador profesional. Si la aprueba, queda visible públicamente dentro de la app (sin tus datos personales asociados). |
| Tipo del hallazgo (fósil o mineral) | Categorización | Curador. Aparece públicamente. |
| Datos declarados por ti (especie, edad geológica, formación, notas libres) | Contexto para la revisión | Curador. La versión revisada por el curador aparece públicamente; tu declaración original queda solo en backend. |
| **Tu correo electrónico** | Para que el curador te notifique si tu aportación se aprueba o rechaza | Curador. **Nunca aparece públicamente** dentro de la app ni asociado a la foto. |
| Tu nombre (opcional) | Identificación puntual ante el curador | Curador. **Nunca aparece públicamente.** |
| Token aleatorio de dispositivo (UUID v4 generado localmente, sin enlace con tu identidad) | Limitar abusos (máximo 5 aportaciones/día por dispositivo) | Sistema. Nunca se comparte. |
| Dirección IP desde la que envías | Limitar abusos (máximo 10 aportaciones/día por IP) | Sistema. Nunca se comparte. |

**Lo que NO se envía nunca al módulo Comunidad:**

- Tus coordenadas GPS. La ubicación del hallazgo permanece en tu dispositivo. La foto aparecerá asociada únicamente a la formación geológica catalogada que el curador determine, no a un punto en el mapa.
- Tu identidad de descubridor (campo nombre/email/organización de la sección "Compartir certificado") ni tu firma criptográfica.
- Tracks GPS, otros hallazgos, ni ningún otro dato distinto al de la aportación concreta.

**Servidor backend:** el backend del módulo es un WordPress controlado por **[NOMBRE_RESPONSABLE]** alojado en **[URL_BACKEND_COMUNIDAD]**, ubicado en el EEE. El acceso del curador requiere autenticación (cuenta WordPress con rol específico).

### 3.5 Datos que **no** recoge la aplicación

- No hay analítica de uso. Ni eventos enviados a servidores propios o de terceros (Firebase Analytics, Google Analytics, Mixpanel, etc.).
- No hay informes de fallos enviados automáticamente.
- No hay identificadores publicitarios (AAID/IDFA).
- No hay anuncios.
- No se recopilan datos biométricos, de salud, financieros, ni de orientación sexual, religión, opinión política o afiliación sindical.

## 4. Permisos del sistema y finalidad

| Permiso | Para qué se usa | ¿Imprescindible? |
|---|---|---|
| Ubicación precisa (`ACCESS_FINE_LOCATION`) | Registrar la posición de un hallazgo y grabar tracks. La ubicación se guarda solo en tu dispositivo. | Sí para la funcionalidad principal. Puedes denegarlo y usar la app sin registrar GPS. |
| Ubicación aproximada (`ACCESS_COARSE_LOCATION`) | Alternativa cuando no hay señal GPS suficiente. | No imprescindible. |
| Cámara (`CAMERA`) | Tomar fotos de hallazgos. | No (puedes seleccionar fotos de la galería). |
| Lectura de imágenes (`READ_MEDIA_IMAGES`, Android 13+) | Permitirte seleccionar fotos existentes de tu galería. | No imprescindible. |
| Almacenamiento (`READ_EXTERNAL_STORAGE`, Android ≤ 12) | Compatibilidad con la misma función anterior en versiones antiguas. | No imprescindible. |
| Internet (`INTERNET`) y estado de red (`ACCESS_NETWORK_STATE`) | Consultar mapas, servicios geológicos y asistente IA si está activo. | Sí si vas a usar capas geológicas o IA. |
| Mantener pantalla activa (`WAKE_LOCK`) | Mantener GPS activo durante la grabación de tracks largos. | No imprescindible. |

Todos los permisos se solicitan en el momento en que la funcionalidad correspondiente se activa por primera vez, no al instalar.

## 5. Exportar y compartir manualmente

La aplicación te permite **exportar** un hallazgo (formato `.fos-card`, ZIP o informe PDF) y compartirlo por el canal que tú elijas (WhatsApp, correo, almacenamiento en la nube, etc.). Esta exportación es **siempre una acción manual e intencionada tuya**; nada se comparte automáticamente.

El archivo exportado incluye:
- Los datos del hallazgo (foto, ubicación si tú así lo eliges, especie, edad, notas).
- Tu identidad de descubridor (nombre, email, organización) si la has rellenado.
- La firma criptográfica del dispositivo (sirve para que el destinatario verifique que el hallazgo no se ha alterado).

Antes de exportar, la aplicación te permite elegir entre tres modos de compartir coordenadas: precisas, difuminadas (km de granularidad) o sin coordenadas. Esta elección depende de la sensibilidad del lugar (yacimiento documentado vs descubrimiento personal) y queda enteramente a tu criterio.

## 6. Bases legales del tratamiento (RGPD art. 6)

Distinguimos por tipo de dato:

| Tratamiento | Base legal | Referencia normativa |
|---|---|---|
| Almacenamiento local de hallazgos, tracks y configuración | Ninguno — no hay tratamiento por el responsable. Los datos no salen de tu dispositivo. | n/a |
| Consultas a servicios cartográficos públicos (IGME, OSM, Wikipedia) | Interés legítimo del usuario en consultar información pública. | RGPD art. 6.1.f |
| Asistente IA opcional (si introduces tu clave) | Consentimiento del usuario al introducir su propia clave de API y enviar el mensaje. | RGPD art. 6.1.a |
| Envío al módulo Comunidad (si está activo) | Consentimiento explícito mediante casilla de aceptación previa al envío. | RGPD art. 6.1.a |
| Mantenimiento de aportaciones aprobadas dentro del catálogo de Comunidad | Consentimiento del usuario que aportó, prorrogado hasta que ejerza su derecho de supresión. | RGPD art. 6.1.a + art. 17 |
| Limitación de abusos (rate-limit por IP/token de dispositivo) | Interés legítimo del responsable en evitar abuso del sistema. | RGPD art. 6.1.f |

## 7. Plazos de conservación

| Categoría | Plazo |
|---|---|
| Datos almacenados solo en tu dispositivo (§3.1) | Mientras la app esté instalada. Al desinstalar se eliminan automáticamente, salvo los archivos que tú hayas exportado fuera del directorio privado de la app. |
| Aportaciones al módulo Comunidad en estado "pendiente" | Hasta que el curador las apruebe, rechace o archive. Tipicamente inferior a 30 días. |
| Aportaciones aprobadas (visibles dentro de la app) | Indefinido mientras dure el servicio, o hasta que ejerzas tu derecho de supresión (ver §8). |
| Aportaciones rechazadas o archivadas | 90 días desde el rechazo, transcurridos los cuales se eliminan automáticamente del backend. |
| Email + nombre de contacto (vinculado a aportaciones) | Mismo plazo que la aportación correspondiente. |
| Direcciones IP + token de dispositivo registradas para rate-limit | 30 días. Sirven solo a efectos de control de abuso. |
| Logs técnicos del servidor backend | Máximo 90 días, anonimizados a partir de los 30 días. |

## 8. Tus derechos

Tienes derecho a **acceder, rectificar, suprimir, oponerte, limitar el tratamiento y a la portabilidad** de tus datos (RGPD arts. 15–22), así como a **retirar tu consentimiento** en cualquier momento sin que afecte a la licitud del tratamiento previo (RGPD art. 7.3).

| Derecho | Cómo ejercerlo |
|---|---|
| Acceso a datos locales (§3.1) | Desde la propia aplicación: pestaña "Hallazgos" y Ajustes → "Tus datos". |
| Supresión de datos locales (§3.1) | Borrar el hallazgo desde la app, o desinstalar la aplicación. |
| Acceso, rectificación o supresión de aportaciones enviadas al módulo Comunidad (§3.4) | Ajustes → "Tus aportaciones a la comunidad" → "Borrar mis aportaciones (RGPD)". Recibirás un email con un enlace de un solo uso. Al hacer click se eliminan TODAS las aportaciones (pendientes y aprobadas) asociadas a tu correo electrónico. Alternativamente puedes escribir a [EMAIL_CONTACTO]. |
| Portabilidad | Para datos locales, usa la función "Exportar todo" en Ajustes (genera un ZIP con la base de datos). Para datos del módulo Comunidad, contacta a [EMAIL_CONTACTO]. |
| Oposición / retirada del consentimiento | Desactivar el módulo Comunidad desde Ajustes deja de enviar nuevas aportaciones. Para suprimir las ya enviadas usa el flujo del párrafo anterior. |
| Reclamación ante la autoridad de control | Agencia Española de Protección de Datos (AEPD): <https://www.aepd.es/> · sede electrónica <https://sedeagpd.gob.es/> |

## 9. Transferencias internacionales

- **Datos almacenados localmente (§3.1):** no hay transferencia, los datos no salen de tu dispositivo.
- **Servicios cartográficos públicos (§3.2):** OSM e iNaturalist tienen servidores fuera del EEE. La información transmitida son coordenadas o nombres de especie, sin datos personales identificables más allá de tu IP. Se ampara en el interés legítimo del usuario en consultar información pública.
- **Asistente IA opcional (§3.3):** Anthropic (EE.UU.) y DeepSeek (China) procesan los mensajes fuera del EEE. Antes de introducir una clave debes verificar las garantías adecuadas que ofrece cada proveedor en sus políticas vinculadas.
- **Módulo Comunidad (§3.4):** el backend está ubicado en el EEE. No hay transferencia internacional de los datos del módulo.

## 10. Seguridad

Medidas técnicas aplicadas:

- **Cifrado en reposo (dispositivo):** las claves criptográficas y las claves de API se guardan en el almacén seguro del sistema operativo (Android Keystore). La base de datos local utiliza permisos del sandbox de aplicación de Android.
- **Cifrado en tránsito:** todas las comunicaciones con servicios externos y con el backend de Comunidad se realizan vía HTTPS/TLS.
- **Firma criptográfica de hallazgos:** cada hallazgo se firma con Ed25519 antes de exportarse, permitiendo a un destinatario verificar autenticidad.
- **Hash SHA-256 de imágenes en el backend de Comunidad:** evita duplicados, facilita la trazabilidad ante reportes de abuso.
- **Rate-limiting:** límites diarios por dispositivo (5) y por IP (10) para prevenir abuso del módulo Comunidad.
- **Acceso restringido al backend:** los curadores acceden con cuenta WordPress autenticada y rol específico. Sin acceso público al área administrativa.

Ningún sistema es invulnerable; en caso de **brecha de seguridad** que afecte a datos personales, se notificará a las personas afectadas y a la AEPD en los plazos exigidos por el RGPD (art. 33–34, máximo 72 horas).

## 11. Menores

La aplicación está orientada a **público adulto** aficionado a la paleontología y la geología. La ficha de Google Play declara el rango de edad correspondiente. La aplicación **no recoge intencionadamente datos de menores de 14 años** ni se dirige a ellos por su contenido o presentación.

Si detectamos que un menor de esa edad ha enviado una aportación al módulo Comunidad, se eliminará sin notificación.

## 12. Patrimonio paleontológico

La aplicación **no es un canal oficial de reporte de patrimonio paleontológico**. La Ley 16/1985 del Patrimonio Histórico Español y las normativas autonómicas de patrimonio cultural reservan el reporte oficial de hallazgos significativos a los Servicios de Patrimonio de las Comunidades Autónomas. Si crees que has encontrado un fósil o yacimiento de relevancia científica:

1. **No lo extraigas.**
2. Reporta su existencia al **Servicio de Patrimonio Cultural de tu CCAA**.
3. Puedes usar la app para registrarlo a efectos personales, pero hacerlo aquí no exime del reporte oficial.

## 13. Resumen de datos para la ficha de Google Play ("Data Safety")

Equivalencias con los campos del formulario de Data Safety de Google Play:

**Datos recopilados y compartidos:**

| Categoría Google | Tipo | ¿Recopilado? | ¿Compartido? | Propósito | Opcional |
|---|---|---|---|---|---|
| Personal info | Email address | Solo si activas el módulo Comunidad y envías una aportación | No compartido — solo lo ve el curador interno | Comunicación con el usuario (notificación de aprobación) | Sí |
| Personal info | Name | Solo si lo rellenas voluntariamente | No compartido | Identificación opcional ante el curador | Sí |
| Photos and videos | Photos | Solo las que enviases al módulo Comunidad | Públicamente visibles dentro de la app si el curador las aprueba | Funcionalidad principal del módulo | Sí |
| Location | Approximate location | No recopilada por el servidor | No | n/a | n/a |
| Location | Precise location | Almacenada solo en tu dispositivo | No | Funcionalidad principal (registro de hallazgos) | Sí |
| App activity | App interactions | No recopilada | No | n/a | n/a |
| App info and performance | Crash logs | No recopilada | No | n/a | n/a |
| Device or other IDs | Device IDs | Token aleatorio generado por la app (UUID v4), no asociado a identificadores publicitarios. Solo se envía al módulo Comunidad para rate-limit. | No | Antiabuso | Sí |

**Prácticas de seguridad:**

- Datos cifrados en tránsito: sí (HTTPS/TLS).
- Puedes solicitar la supresión de tus datos: sí (RGPD art. 17).
- La app sigue las Familias Política de Google Play (si aplica): no aplica — orientación adulta.

## 14. Cambios en esta política

Si una versión futura de la aplicación cambia el modo en que se procesan datos —en particular, si activa nuevos servicios o cambia el destinatario del módulo Comunidad— se publicará una versión revisada de esta política con antelación. Los cambios sustanciales se anunciarán en la propia aplicación (pantalla de "Novedades" o aviso modal en el primer arranque tras la actualización) antes de que el cambio entre en vigor.

La versión anterior de esta política queda accesible a efectos de consulta.

## 15. Contacto y autoridad de control

| | |
|---|---|
| **Contacto del responsable** | [EMAIL_CONTACTO] · [DIRECCIÓN_POSTAL] |
| **Autoridad de control** | Agencia Española de Protección de Datos · C/ Jorge Juan, 6 · 28001 Madrid · <https://www.aepd.es/> |
| **Sede electrónica para reclamaciones** | <https://sedeagpd.gob.es/sede-electronica-web/> |

---

*Esta política se ha redactado siguiendo las directrices del Reglamento (UE) 2016/679 (RGPD), la Ley Orgánica 3/2018 de Protección de Datos Personales y garantía de los derechos digitales (LOPDGDD), las directrices de la AEPD sobre desarrollo de aplicaciones móviles y los requisitos de la Sección "Data Safety" de Google Play.*
