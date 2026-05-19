#!/usr/bin/env bash
# Captura de pantalla del móvil Android conectado por adb, pensada para
# preparar la ficha de Play Store de Fósiles.
#
# Uso:
#   ./scripts/capturar.sh                 → siguiente número (01, 02, ...)
#   ./scripts/capturar.sh mapa-igme       → guarda como capturas/NN-mapa-igme.png
#   ./scripts/capturar.sh --abrir         → lanza la app y captura la 01
#   ./scripts/capturar.sh --secuencia     → guía interactiva de las 6 capturas
#                                            principales para la ficha de Play Store
#   ./scripts/capturar.sh --listar        → muestra capturas existentes
#
# Pre-requisitos:
#   - adb instalado y en PATH.
#   - Móvil conectado por USB con depuración USB activada.
#   - App `com.josu.fosiles` instalada en el móvil.

set -euo pipefail

paquete_app="com.josu.fosiles"
directorio_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
directorio_capturas="$directorio_script/../docs/play-store/capturas"
mkdir -p "$directorio_capturas"

verificar_dispositivo_conectado() {
  local dispositivos
  dispositivos=$(adb devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l)
  if [[ $dispositivos -eq 0 ]]; then
    echo "ERROR: ningún dispositivo Android conectado." >&2
    echo "       Conecta el móvil por USB con depuración activada." >&2
    exit 1
  fi
  if [[ $dispositivos -gt 1 ]]; then
    echo "AVISO: hay más de un dispositivo conectado. adb usará el primero:" >&2
    adb devices >&2
  fi
}

siguiente_numero() {
  local existentes
  existentes=$(find "$directorio_capturas" -maxdepth 1 -name '[0-9][0-9]-*.png' 2>/dev/null | wc -l)
  printf "%02d" $((existentes + 1))
}

capturar() {
  local nombre_destino="$1"
  local ruta_destino="$directorio_capturas/$nombre_destino"
  local ruta_temporal_movil="/sdcard/captura-fosiles-temporal.png"

  adb shell screencap -p "$ruta_temporal_movil"
  adb pull "$ruta_temporal_movil" "$ruta_destino" >/dev/null
  adb shell rm "$ruta_temporal_movil"

  local tamano
  tamano=$(du -h "$ruta_destino" | cut -f1)
  echo "Guardado: $ruta_destino ($tamano)"
}

abrir_app() {
  echo "Lanzando $paquete_app en el móvil..."
  adb shell monkey -p "$paquete_app" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  echo "Esperando 3 segundos a que cargue..."
  sleep 3
}

listar_capturas() {
  if compgen -G "$directorio_capturas/*.png" > /dev/null; then
    ls -lh "$directorio_capturas"/*.png | awk '{print $9, "  ", $5}'
  else
    echo "(no hay capturas todavía)"
  fi
}

secuencia_guiada() {
  local etapas=(
    "inicio|Vuelve a la pantalla de inicio (botón Inicio en barra inferior)."
    "mapa-igme|Toca 'Mapa'. Espera a que carguen los marcadores y la capa IGME esté visible."
    "ficha-hallazgo|Toca un marcador o entrada de la lista para abrir la ficha de un hallazgo con foto, edad y formación."
    "estrato|En 'Nuevo hallazgo' (botón + de la barra inferior), pulsa 'Medir' en la sección de orientación. Inclina el móvil ~35° antes de capturar para que dip y strike muestren valores realistas (si está plano sale el aviso naranja)."
    "linea-tiempo|Pulsa 'Guía' en la barra inferior y luego el icono de línea de tiempo en la barra superior (tooltip 'Línea del tiempo')."
    "guia|Abre la guía de identificación."
    "mapas-offline|Pulsa 'Ajustes' (engranaje en barra inferior), baja a la sección de caché de mapas y pulsa 'Descargar zona'."
  )
  echo "Modo secuencia: 7 capturas guiadas. En cada paso navega a la pantalla"
  echo "indicada en el móvil y pulsa Enter aquí para disparar la captura."
  echo "Ctrl+C cancela. Las capturas se guardan en docs/play-store/capturas/."
  echo
  for etapa in "${etapas[@]}"; do
    local nombre="${etapa%%|*}"
    local instruccion="${etapa#*|}"
    echo "▶  $instruccion"
    read -r -p "   Enter para capturar como NN-${nombre}.png (o 's' + Enter para saltar): " respuesta
    if [[ "$respuesta" == "s" ]]; then
      echo "   (saltada)"
      continue
    fi
    capturar "$(siguiente_numero)-${nombre}.png"
    echo
  done
  echo "Secuencia completada. Capturas guardadas:"
  listar_capturas
}

verificar_dispositivo_conectado

case "${1:-}" in
  --listar|-l)
    listar_capturas
    ;;
  --abrir|-a)
    abrir_app
    capturar "$(siguiente_numero)-inicio.png"
    ;;
  --secuencia|-s)
    secuencia_guiada
    ;;
  --ayuda|-h|--help)
    grep '^#' "$0" | sed 's/^# \?//'
    ;;
  '')
    capturar "$(siguiente_numero)-captura.png"
    ;;
  *)
    capturar "$(siguiente_numero)-${1}.png"
    ;;
esac
