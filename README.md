# podman-sparrow

> Sparrow Wallet en contenedor rootless, con tráfico forzado por Tor y máximo aislamiento SELinux.

Este repositorio empaqueta [Sparrow Wallet](https://sparrowwallet.com/) dentro de un contenedor [Podman](https://podman.io/) rootless sobre Fedora. El objetivo es ejecutar una wallet Bitcoin sin que el software toque el sistema anfitrión, con todo el tráfico de red saliendo por un contenedor Tor dedicado.

---

## Características

- **Rootless**: el contenedor corre con tu UID/GID, sin privilegios de root.
- **SELinux enforcing**: usa `container_runtime_t` para permitir X11 sin desactivar SELinux.
- **Tor por defecto**: todo el tráfico de Sparrow sale por SOCKS5 a través de un contenedor Tor en la red `tornet`.
- **Sin GPU**: rendering por software (`-Dprism.order=sw`), eliminando el vector de ataque del driver DRI.
- **Datos fuera del contenedor**: la wallet y la configuración persisten en un directorio del host que tú eliges.
- **Integración escritorio**: incluye lanzador `.desktop` y script `sparrow-podman` desplegable con [GNU Stow](https://www.gnu.org/software/stow/).

---

## Requisitos

- Fedora (testeado en Fedora Atomic 44 con Sway)
- `podman` (rootless)
- `java-25-openjdk` en el host (solo para verificación de firma en `build.sh`)
- `gpg` y `curl` en el host
- Un contenedor/quadlet de Tor con:
  - Red Podman `tornet`
  - `NetworkAlias=podmantor`
  - Puerto `9050` (SOCKS5)
- `stow` (opcional, para instalar el lanzador)

---

## Estructura

```
podman-sparrow/
├── build.sh                      # Descarga, verifica y construye la imagen
├── Containerfile                 # Imagen mínima de Fedora con Sparrow
├── config.example                # Variables de entorno (copiar a ~/.config/sparrow-container/config)
├── .gitignore
└── stow/
    └── sparrow/
        └── .local/
            ├── bin/
            │   └── sparrow-podman           # Script de lanzamiento
            └── share/
                └── applications/
                    └── sparrow-podman.desktop  # Entrada de escritorio
```

---

## Instalación

### 1. Clonar

```bash
git clone https://github.com/laperl/podman-sparrow.git ~/src/podman-sparrow
cd ~/src/podman-sparrow
```

### 2. Desplegar lanzador (con Stow)

```bash
stow -d stow -t ~ sparrow
```

Esto crea los enlaces simbólicos:
- `~/.local/bin/sparrow-podman`
- `~/.local/share/applications/sparrow-podman.desktop`

Actualiza la base de datos de escritorio para que aparezca en `wofi`, `fuzzel` o `rofi`:

```bash
update-desktop-database ~/.local/share/applications
```

### 3. Configurar

```bash
mkdir -p ~/.config/sparrow-container
cp config.example ~/.config/sparrow-container/config
```

Edita `~/.config/sparrow-container/config` y ajusta `SPARROW_DATA_DIR`:

```bash
SPARROW_DATA_DIR="$HOME/sparrowwallet"
```

El directorio debe existir antes de lanzar Sparrow:

```bash
mkdir -p "$HOME/sparrowwallet"
```

### 4. Construir imagen

```bash
./build.sh [VERSION]
```

Ejemplo:

```bash
./build.sh 2.5.3
```

Esto:
1. Descarga el RPM y el manifest de firmas desde GitHub Releases.
2. Verifica la firma PGP del desarrollador (Craig Raw).
3. Verifica el checksum SHA256 del RPM.
4. Construye `localhost/sparrow:latest`.
5. Limpia los archivos temporales.

> **Nota:** Si no indicas versión, usa `2.5.3` por defecto. Revisa la [página de releases](https://github.com/sparrowwallet/sparrow/releases) para actualizar.

---

## Uso

### Desde terminal

```bash
sparrow-podman
```

### Desde el lanzador gráfico

Busca **"Sparrow Wallet"** en tu launcher (`$mod+d` en Sway) o usa el keybinding si lo has configurado.

### Configuración de servidor en Sparrow

La primera vez, configura el servidor para que use Tor:

1. Abre Sparrow.
2. Ve a la pestaña **Server** (abajo a la derecha).
3. Tipo: **Public Server**.
4. Activa **Use Proxy**.
5. **Proxy URL:** `podmantor`
6. **Port:** `9050`
7. Selecciona un servidor de la lista (ej. `blockstream.info:700`).
8. **Test Connection** → debe ponerse verde.

> `podmantor` es el `NetworkAlias` del contenedor Tor dentro de la red `tornet`. Desde el contenedor Sparrow se resuelve por DNS interno de Podman.

---

## Actualizar Sparrow

Cuando salga una nueva versión:

```bash
cd ~/src/podman-sparrow
./build.sh 2.5.4   # o la versión nueva
```

La imagen anterior se reemplaza por `localhost/sparrow:latest`. Los datos de wallet no se tocan porque viven fuera del contenedor, en `SPARROW_DATA_DIR`.

---

## Seguridad

| Medida | Qué protege |
|--------|-------------|
| `--userns=keep-id` | El contenedor corre con tu UID, no root. |
| `--cap-drop=ALL` | Sin capabilities de Linux. |
| `--security-opt no-new-privileges:true` | Evita escalada de privilegios. |
| `--security-opt label=type:container_runtime_t` | Permite X11 sin desactivar SELinux completamente. |
| `--read-only` implícito en rootfs | El sistema de archivos del contenedor es inmutable (excepto los volúmenes montados). |
| `-Dprism.order=sw` | Rendering por software; no expone `/dev/dri`. |
| `--network tornet` | Sparrow solo puede hablar con la red interna donde está Tor. |
| `xhost +si:localuser:$(whoami)` | Autorización X11 mínima, solo para tu usuario. |

**Importante:** Este contenedor expone `--device /dev/bus/usb` y `--device /dev/hidraw0` para hardware wallets. Si no usas HW, puedes eliminar esas líneas. Si usas una HW específica, considera restringir a un dispositivo USB concreto mediante reglas `udev`.

---

## Solución de problemas

### "No display detected"

SELinux está bloqueando el socket X11. Verifica que usas `--security-opt label=type:container_runtime_t` y que has ejecutado `xhost +si:localuser:$(whoami)`.

### "Retries exhausted" al probar conexión Tor

1. Verifica que el contenedor Tor está activo: `systemctl --user status tor-client.service`
2. Comprueba que Sparrow está en la red `tornet`:
   ```bash
   podman inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' sparrowwallet
   ```
3. Si no aparece `tornet`, asegúrate de que `SPARROW_NETWORK="tornet"` está en tu config.

### El contenedor no arranca porque `sparrowwallet` ya existe

El script usa `--replace`, que mata el contenedor anterior automáticamente. Si falla:

```bash
podman rm -f sparrowwallet
```

---

## Licencia

MIT. El código es tuyo, las claves son tuyas, la responsabilidad es tuya.

> **Aviso:** Este software se proporciona sin garantía. Verifica siempre los checksums y firmas PGP. Nunca compartas tu frase semilla ni tu passphrase.
