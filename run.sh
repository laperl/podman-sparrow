#!/bin/bash
set -euo pipefail

# --- 1. Cargar configuración del usuario (XDG compliant) ---
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sparrow-container"
CONFIG_FILE="${CONFIG_DIR}/config"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
fi

# --- 2. Defaults solo para lo no sensible ---
TOR_SERVICE="${TOR_SERVICE:-tor-container.service}"
TOR_HOST="${TOR_HOST:-host.containers.internal}"
TOR_PORT="${TOR_PORT:-9050}"

# --- 3. SPARROW_DATA_DIR: obligatorio, sin default que filtre rutas ---
if [[ -z "${SPARROW_DATA_DIR:-}" ]]; then
  echo "[!] ERROR: SPARROW_DATA_DIR no está definido." >&2
  echo "    Crea ${CONFIG_FILE} con:" >&2
  echo "    SPARROW_DATA_DIR=\"\$HOME/ruta/a/tu/wallet\"" >&2
  exit 1
fi

if [[ ! -d "${SPARROW_DATA_DIR}" ]]; then
  echo "[!] ERROR: El directorio no existe: ${SPARROW_DATA_DIR}" >&2
  exit 1
fi

# --- 4. Asegurar que Tor está corriendo ---
if ! systemctl --user is-active --quiet "${TOR_SERVICE}" 2>/dev/null; then
  echo "[!] ${TOR_SERVICE} no está activo. Arrancando..."
  systemctl --user start "${TOR_SERVICE}"

  for i in {1..10}; do
    if nc -z "${TOR_HOST}" "${TOR_PORT}" 2>/dev/null; then
      echo "[+] Proxy SOCKS de Tor listo."
      break
    fi
    sleep 1
  done
else
  echo "[+] ${TOR_SERVICE} ya está activo."
fi

# --- 5. X11: autorización mínima (más seguro que +local:) ---
# Solo permite al usuario actual conectarse al display
xhost "+si:localuser:$(whoami)" 2>/dev/null || true

# --- 6. Lanzar ---
exec podman run --rm -it \
  --userns=keep-id \
  --group-add keep-groups \
  --security-opt label=type:container_runtime_t \
  --security-opt no-new-privileges:true \
  --cap-drop=ALL \
  --device /dev/bus/usb \
  --device /dev/hidraw0 \
  -e DISPLAY=:0 \
  -e XDG_RUNTIME_DIR=/tmp \
  -e _JAVA_OPTIONS="-Dprism.order=sw" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v "${SPARROW_DATA_DIR}:/home/cripto/.sparrow:Z" \
  localhost/sparrow:latest
