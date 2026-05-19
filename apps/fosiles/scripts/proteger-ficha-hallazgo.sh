#!/usr/bin/env bash
# proteger-ficha-hallazgo.sh — sustituye en una captura de Play Store de la
# pantalla "ficha de hallazgo" las coordenadas precisas reales por un valor
# redondeado, para no exponer un yacimiento sensible al subir la captura.
#
# Pensado para capturas tomadas con `scripts/capturar.sh` en un Xiaomi
# Redmi Note 8 (1080x2340). Si la resolución varía, ajustar las constantes
# de offset al final del archivo.
#
# Uso:
#   ./scripts/proteger-ficha-hallazgo.sh INPUT.png
#   ./scripts/proteger-ficha-hallazgo.sh INPUT.png OUTPUT.png
#   ./scripts/proteger-ficha-hallazgo.sh INPUT.png OUTPUT.png "TEXTO SUSTITUTO"
#
# Por defecto escribe junto al INPUT como ${nombre}-protegida.png y usa el
# texto "≈ 42.7, -2.0 (zona)" — mismo formato que la app emite pero con
# un decimal de precisión, suficiente para "Pirineo navarro" pero no para
# guiar a nadie al afloramiento.

set -euo pipefail

input="${1:?Falta el archivo PNG de entrada}"
default_output="${input%.png}-protegida.png"
output="${2:-$default_output}"
texto_sustituto="${3:-≈ 42.7, -2.0 (zona)}"

color_fondo="#F3F4E9"
color_texto="#1A1A1A"

# Posiciones medidas en la captura 1080x2340 de la ficha de hallazgo
# (recortada en /tmp y verificada visualmente):
#  - Fila "Coordenadas":      Y = 1390..1465, X del valor = 290..1080
#  - Anclaje del texto nuevo: X = 290, baseline = 1440
rect_x1=290
rect_y1=1390
rect_x2=1080
rect_y2=1465
texto_x=290
texto_y=1440

magick "$input" \
  -fill "$color_fondo" -draw "rectangle ${rect_x1},${rect_y1} ${rect_x2},${rect_y2}" \
  -font DejaVu-Sans -pointsize 40 -fill "$color_texto" \
  -annotate "+${texto_x}+${texto_y}" "$texto_sustituto" \
  "$output"

echo "Guardado: $output"
