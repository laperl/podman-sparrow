#!/bin/bash
set -euo pipefail

# --- 1. Cargar configuración ---
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sparrow-container"
CONFIG_FILE="${CONFIG_DIR}/config"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
fi

# --- 2. Defaults (arquitectura Tor en red dedicada) ---
TOR_SERVICE="${TOR_SERVICE:-tor-client.service}"
TOR_HOST="${TOR_HOST:-podmantor}"
TOR_PORT="${TOR_PORT:-9050}"
SPARROW_NETWORK="${SPARROW_NETWORK:-tornet}"

# --- 3. Validar SPARROW_DATA_DIR ---
if [[ -z "${SPARROW_DATA_DIR:-}" ]]; then
  cat >&2 <<EOF
[!] ERROR: SPARROW_DATA_DIR no definido.

Crea el archivo ${CONFIG_FILE} con:

SPARROW_DATA_DIR="\$HOME/ruta/a/sparrowwallet"
EOF
  exit 1
fi

if [[ ! -d "${SPARROW_DATA_DIR}" ]]; then
  echo "[!] ERROR: El directorio no existe: ${SPARROW_DATA_DIR}" >&2
  exit 1
fi

# --- 4. Asegurar que Tor está corriendo ---
if ! systemctl --user is-active --quiet "${TOR_SERVICE}" 2>/dev/null; then
  echo "[!] ${TOR_SERVICE} no está activo. Arrancando..."
  if ! systemctl --user start "${TOR_SERVICE}"; then
    echo "[!] ERROR: No se pudo arrancar ${TOR_SERVICE}" >&2
    exit 1
  fi

  echo "[*] Esperando proxy SOCKS en ${TOR_HOST}:${TOR_PORT}..."
  for i in {1..15}; do
    # Si Sparrow va a estar en la misma red, no podemos hacer nc desde el host
    # usando el alias DNS. Pero el puerto 9050 está publicado en 127.0.0.1 del host,
    # así que verificamos por ahí para confirmar que Tor está listo.
    if nc -z 127.0.0.1 "${TOR_PORT}" 2>/dev/null; then
      echo "[+] Proxy SOCKS respondiendo."
      break
    fi
    sleep 1
  done
else
  echo "[+] ${TOR_SERVICE} ya está activo."
fi

# --- 5. X11 ---
xhost "+si:localuser:$(whoami)" 2>/dev/null || true

# --- 6. Construir flags de red ---
NETWORK_FLAGS=()
if [[ -n "${SPARROW_NETWORK}" ]]; then
  NETWORK_FLAGS=(--network "${SPARROW_NETWORK}")
fi

# --- 7. Lanzar Sparrow ---
echo "[*] Lanzando Sparrow en red '${SPARROW_NETWORK}' -> Tor en ${TOR_HOST}:${TOR_PORT}"
exec podman run --rm -it \
  --name "sparrowwallet" \
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
  "${NETWORK_FLAGS[@]}" \
  localhost/sparrow:latest
