#!/bin/bash
set -euo pipefail

VERSION="${1:-2.5.3}"
ARCH="x86_64"
RPM="sparrowwallet-${VERSION}-1.${ARCH}.rpm"
BASE_URL="https://github.com/sparrowwallet/sparrow/releases/download/${VERSION}"
MANIFEST="sparrow-${VERSION}-manifest.txt"
MANIFEST_SIG="${MANIFEST}.asc"

# Clave PGP de Craig Raw (desarrollador)
GPG_KEY="D4D0D3202FC06849A257B38DE94618334C674B40"

echo "[*] Descargando Sparrow ${VERSION}..."
curl -fsSL -o "${RPM}" "${BASE_URL}/${RPM}"
curl -fsSL -o "${MANIFEST}" "${BASE_URL}/${MANIFEST}"
curl -fsSL -o "${MANIFEST_SIG}" "${BASE_URL}/${MANIFEST_SIG}"

echo "[*] Verificando firma PGP del manifest..."
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "${GPG_KEY}" 2>/dev/null || true
gpg --verify "${MANIFEST_SIG}" "${MANIFEST}"

echo "[*] Verificando checksum del RPM..."
sha256sum --check --ignore-missing "${MANIFEST}"

echo "[*] Construyendo imagen Podman..."
podman build -t localhost/sparrow:latest -f Containerfile .

echo "[*] Limpieza..."
rm -f "${RPM}" "${MANIFEST}" "${MANIFEST_SIG}"

echo "[+] Imagen localhost/sparrow:latest lista."
