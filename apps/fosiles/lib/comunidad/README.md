# `lib/comunidad/` — Ciencia ciudadana con curaduría experta

Módulo de aportaciones a una comunidad de fósiles/minerales con
curación por un geólogo o paleontólogo profesional. **Inactivo en
producción** hasta que se ponga `kFeatureComunidadHabilitada` a `true`
en `feature_flag_comunidad.dart`.

## Estado actual

- Scaffolding completo del cliente Dart, modelos, UI (diálogo +
  pantalla de galería) e identidad de dispositivo.
- **Sin backend desplegado**. Los endpoints `/nuevo-ser/v1/fosiles/*`
  todavía no existen en `wp-plugin/nuevo-ser-core`.
- **Sin cableado en la UI principal**. Mientras el flag esté a `false`,
  el módulo no se llama desde ningún sitio del flujo normal.
- Tree-shaking elimina las ramas inalcanzables del APK release.

## Antes de activar

Lista de chequeo (ver plan completo en
`~/.claude/plans/magical-tumbling-thunder.md`):

1. **Curador**: geólogo o paleontólogo profesional dispuesto a revisar
   aportaciones (20-30 min/semana mínimo). Sin esto, no se activa.
2. **Backend desplegado**: extender `wp-plugin/nuevo-ser-core` con:
   - 2 roles WP nuevos (`nuevoser_curador_fosiles`, `nuevoser_admin_fosiles`)
   - 3 tablas (`wp_ns_fosiles_aportaciones`, `wp_ns_fosiles_fotos_blob`,
     `wp_ns_fosiles_formaciones_catalogadas`)
   - Endpoints REST públicos y privados bajo `/nuevo-ser/v1/fosiles/*`
   - Submenú de moderación en wp-admin con capability
     `nuevoser_fosiles_revisar`
   - Rate-limit por IP + token de dispositivo
3. **Política de privacidad + T&Cs** revisados por jurista (~200-500 €
   puntual).
4. **Hosting** del WordPress con espacio para fotos (~500 MB primer año).
5. **Cambiar** `urlBaseComunidad` en `feature_flag_comunidad.dart` para
   apuntar al servidor real.
6. **Poner** `kFeatureComunidadHabilitada = true` y publicar nueva APK.

## Estructura del módulo

```
lib/comunidad/
├── feature_flag_comunidad.dart      const bool global + URL base
├── modelo_foto_comunidad.dart       FotoComunidad + ResultadoSubidaAportacion
├── identidad_dispositivo.dart       UUID v4 anónimo, por instalación
├── cliente_comunidad.dart           HTTP: subir, listar, borrar (RGPD)
├── dialogo_compartir_comunidad.dart Modal de subida desde ficha hallazgo
└── pantalla_fotos_comunidad.dart    Galería de fotos por formación
```

## Decisiones de diseño relevantes

- **Anónimo desde la UI pública**: el aficionado no tiene cuenta. Email
  y nombre se mandan junto a la aportación SOLO para que el curador
  pueda notificar aprobación/rechazo. Nunca se publican.
- **Cero coordenadas, cero identidad criptográfica**: las aportaciones
  son fotos asociadas a una formación geológica catalogada, no a un
  punto. Las coords precisas y la firma Ed25519 del hallazgo local
  NUNCA viajan al backend de la comunidad.
- **Rate-limit por dispositivo + IP**: la única defensa antispam sin
  cuentas. 5 subidas/día por dispositivo, 10 por IP.
- **Derecho de borrado RGPD**: endpoint público que manda un email con
  enlace de un solo uso. Al hacer click, borra todas las aportaciones
  vinculadas a ese email (incluso aprobadas).
- **Reuso del catálogo `formacion_a_fosiles.dart`**: las formaciones
  catalogadas las gestiona el admin desde wp-admin. La app sincroniza
  por slug (`codigo` de cada `CatalogoFormacion`).
