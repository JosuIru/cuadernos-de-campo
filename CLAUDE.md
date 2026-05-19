# Cuadernos de Campo — CLAUDE.md

Cerebro persistente del repo. Se lee al inicio de cada sesión.

## Encuadre

Repo separado de `nuevo-ser/` el 2026-05-19. Aloja **dos apps de operador para adulto aficionado**:

- `apps/fosiles/` — paleontología y mineralogía, con asistente IGME, módulo opcional de comunidad.
- `apps/naturaleza/` — avistamientos de fauna y flora.

**No son apps Kids** y por tanto:
- NO aplica la voz adulta amable de la biblia del cuaderno Kids.
- NO aplican los hard limits (sin XP/quiz/estadísticas). Estas apps SÍ pueden tener quiz y estadísticas legítimamente.
- SÍ respetan privacidad estructural cuando sincronizan (NUNCA coordenadas precisas al backend).
- NO se fusionan con el cuaderno Kids.

## Dependencia con nuevo-ser/

`packages/nuevo_ser_core` del repo sibling `nuevo-ser/` se importa por `path: ../../../nuevo-ser/packages/nuevo_ser_core` en los pubspec.yaml. Layout asumido:

```
~/Projects/games/
├── nuevo-ser/           ← Kids + Solera + plataforma compartida
└── cuadernos-de-campo/  ← este repo
```

`nuevo_ser_core` lo siguen usando 4 apps Kids + 6 Solera del repo nuevo-ser; no se puede mover aquí sin duplicar.

## Backend de Fósiles Comunidad

El wp-plugin que sirve el módulo "ciencia ciudadana" de Fósiles vive en `nuevo-ser/wp-plugin/nuevo-ser-core/`. Cuando se active el flag, este repo solo contiene el cliente Flutter; el wp-plugin se despliega aparte (WordPress + MySQL + SMTP).

## Estado actual

**Fósiles** — v1.0.14+15. Cobertura geológica desde Precámbrico hasta hoy (14 períodos, ~103 fósiles, 41 formaciones catalogadas). Asistente IGME funcionando en español, sin "Euskal Herria" en el branding. Política de privacidad v2.0 redactada (pendiente revisión jurídica + rellenar placeholders). Módulo Comunidad scaffolded e inactivo (gated por `kFeatureComunidadHabilitada=false`).

**Naturaleza** — versión heredada del monorepo. Bumps de versión sincronizados con fósiles cuando ha habido releases conjuntos.

## Reglas de interacción

- Variables/clases/archivos en **castellano descriptivo**.
- Sin emojis. Tono adulto.
- Tests existentes son mínimos; código preexistente del operador.
- Commits pequeños (<10 archivos salvo setup).

## Comandos habituales

```bash
export PATH="$HOME/flutter/bin:$PATH"
( cd apps/fosiles && flutter analyze )
( cd apps/fosiles && flutter test )
( cd apps/fosiles && flutter build apk --release )
( cd apps/fosiles && flutter run -d linux )
```

Para regenerar el seed del catálogo de formaciones (escribe en `../../../nuevo-ser/wp-plugin/...`):

```bash
( cd apps/fosiles && flutter test test/exportar_formaciones_a_json_test.dart )
```
