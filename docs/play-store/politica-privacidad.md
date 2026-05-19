# Política de privacidad — Fósiles (Cuaderno de Campo)

**Última actualización:** 2026-05-19
**Versión de la app:** 1.0.13

> Borrador para revisión humana. Sustituir `[NOMBRE_RESPONSABLE]`, `[DIRECCIÓN_POSTAL]`, `[EMAIL_CONTACTO]` y `[URL_PÚBLICA_DE_ESTA_PÁGINA]` por los valores definitivos antes de publicar. La URL definitiva tiene que servir esta página públicamente desde el dominio que finalmente se registre.

## 1. Responsable del tratamiento

Esta aplicación está desarrollada y mantenida por **[NOMBRE_RESPONSABLE]**, con domicilio en **[DIRECCIÓN_POSTAL]** y dirección de contacto **[EMAIL_CONTACTO]**.

## 2. Resumen en una frase

Fósiles es un cuaderno de campo: todos tus hallazgos, fotos, tracks GPS y notas se guardan **localmente en tu dispositivo**. La aplicación no tiene servidor propio donde se recojan tus datos personales. Las únicas comunicaciones externas son consultas a servicios cartográficos y científicos públicos, y, si tú lo eliges, peticiones al proveedor de inteligencia artificial cuya clave de API tú mismo configures.

## 3. Datos que la aplicación procesa y dónde se almacenan

### 3.1 Datos almacenados solo en tu dispositivo

Estos datos **no salen del teléfono** salvo que tú decidas exportarlos o compartirlos manualmente. Se guardan en la base de datos local (SQLite) y en preferencias internas:

- Hallazgos (fósiles y minerales) con su ubicación GPS precisa, fecha, fotografía, especie declarada, edad geológica, formación, orientación de estrato (strike/dip), notas y certificación criptográfica.
- Tracks GPS de salidas de campo.
- Fotografías tomadas con la cámara o seleccionadas de tu galería para vincularlas a un hallazgo.
- Tu identidad de descubridor (nombre, correo electrónico, organización) si decides rellenarla en Ajustes. Se usa para firmar tus hallazgos exportables.
- Tu clave criptográfica privada Ed25519, generada localmente y almacenada cifrada en el almacén seguro del sistema operativo (Android Keystore). Se usa para firmar tus hallazgos.
- Tus claves de API de proveedores de IA (si las introduces) en el almacenamiento seguro de la aplicación.
- Preferencias de configuración y mapas descargados para uso sin conexión.

### 3.2 Comunicaciones con servicios externos

La aplicación contacta con los siguientes servicios cuando tú usas la funcionalidad que los requiere. En ninguno de estos casos la aplicación les envía tus datos personales identificables; lo que envían es la información estrictamente necesaria para que el servicio responda (por ejemplo, las coordenadas del fragmento de mapa que se está mostrando). Estos servicios verán la dirección IP de tu dispositivo, como en cualquier navegación web.

| Servicio | Cuándo se contacta | Qué se envía |
|---|---|---|
| OpenStreetMap (tiles cartográficos) | Al mostrar el mapa base | Coordenadas del tile solicitado |
| IGME (Instituto Geológico y Minero de España, servicios WMS/WFS) | Al mostrar la capa geológica nacional | Coordenadas del área visible |
| GEODE (Mapa Geológico Continuo de España) | Al consultar formaciones geológicas | Coordenadas de la consulta |
| Servicios de mareas | Al consultar el horario de mareas para una localización costera | Coordenadas de la consulta |
| Wikipedia / iNaturalist | Al mostrar galerías de referencia para identificar especies | Nombre de la especie consultada |

### 3.3 Asistente de inteligencia artificial (opcional, bajo control del usuario)

La aplicación incluye un asistente conversacional que solo funciona si **tú introduces tu propia clave de API** de uno de los siguientes proveedores:

- **Anthropic Claude** (`api.anthropic.com`)
- **DeepSeek** (`api.deepseek.com`)

Cuando uses el chat, el contenido de tus mensajes (texto y, si las adjuntas, imágenes) se envía directamente desde tu dispositivo al proveedor que hayas configurado. El desarrollador de esta aplicación **no intermedia, no almacena ni accede** a esos mensajes. El tratamiento que el proveedor de IA haga de esos datos se rige por su propia política de privacidad:

- Anthropic — https://www.anthropic.com/legal/privacy
- DeepSeek — https://chat.deepseek.com/downloads/DeepSeek%20Privacy%20Policy.html

### 3.4 Comunidad y backend propio

La aplicación contiene módulos de "Comunidad" (aportaciones revisadas por curadores) preparados para una futura activación. **En esta versión están desactivados** y no realizan ninguna comunicación de red. Si en una versión futura se activan, esta política de privacidad se actualizará con antelación y se requerirá tu consentimiento explícito antes de cualquier envío.

### 3.5 Datos que **no** recoge la aplicación

- No hay analítica de uso, ni eventos enviados a servidores propios o de terceros (Firebase Analytics, Google Analytics, etc.).
- No hay informes de fallos enviados automáticamente.
- No hay identificadores publicitarios.
- No hay anuncios.

## 4. Permisos del sistema y para qué se usan

| Permiso | Para qué se usa |
|---|---|
| Ubicación precisa (`ACCESS_FINE_LOCATION`) | Registrar la posición exacta de un hallazgo o grabar un track de la salida de campo. La ubicación se guarda solo en tu dispositivo. |
| Ubicación aproximada (`ACCESS_COARSE_LOCATION`) | Alternativa cuando no hay señal GPS suficiente. |
| Cámara (`CAMERA`) | Tomar fotos de hallazgos y vincularlas a la ficha. |
| Lectura de imágenes (`READ_MEDIA_IMAGES`) | Permitir que selecciones fotos ya existentes en tu galería para añadirlas a un hallazgo. |
| Almacenamiento (`READ_EXTERNAL_STORAGE`, hasta Android 12) | Compatibilidad con versiones antiguas para la misma función anterior. |
| Internet y estado de red (`INTERNET`, `ACCESS_NETWORK_STATE`) | Consultar mapas IGME/OSM, servicios geológicos, mareas y el asistente de IA si lo activas. |
| Despertar pantalla (`WAKE_LOCK`) | Mantener el GPS activo durante la grabación de un track sin que el sistema lo interrumpa. |

## 5. Compartir hallazgos con terceros (acción explícita tuya)

La aplicación permite que tú **exportes** un hallazgo como archivo `.fos-card` o como ZIP, o que generes un informe PDF, y que lo compartas por los canales que tú elijas (WhatsApp, correo, Drive, etc.). Esta exportación es siempre una acción manual e intencionada por tu parte; nada se comparte automáticamente. El archivo exportado incluye la información del hallazgo, tu identidad de descubridor si la has rellenado, y la firma criptográfica del dispositivo.

## 6. Retención

Los datos viven en tu dispositivo mientras la aplicación esté instalada. Al desinstalarla se eliminan, salvo los archivos que tú hayas exportado fuera del directorio privado de la aplicación.

Puedes borrar manualmente cualquier hallazgo o track desde la propia aplicación.

## 7. Tus derechos

Dado que ningún dato personal se transmite a un servidor controlado por el desarrollador, no hay base de datos remota desde la que ejercer acceso, rectificación, supresión o portabilidad: tienes el control directo desde la propia aplicación. Si surgiese cualquier duda relacionada con esta política, puedes escribir a **[EMAIL_CONTACTO]**.

## 8. Menores

La aplicación está orientada a público adulto aficionado a la paleontología y la geología. No está diseñada para menores de 13 años ni recoge intencionadamente datos de menores.

## 9. Cambios en esta política

Si una versión futura de la aplicación cambia el modo en que se procesan datos —especialmente si se activa la subida de aportaciones a un backend de comunidad— se publicará una versión revisada de esta política antes de que ese cambio entre en vigor, y se solicitará nuevamente el consentimiento del usuario cuando sea necesario.

## 10. Contacto

Para cualquier consulta relacionada con esta política o con el tratamiento de datos en la aplicación, escribe a **[EMAIL_CONTACTO]**.
