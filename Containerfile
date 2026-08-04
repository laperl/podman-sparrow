# Utilizar Fedora Latest como base
FROM registry.fedoraproject.org/fedora:latest

LABEL maintainer="Jaume"
LABEL description="Imagen base de Fedora con sparrowwallet para aislamiento rootless en Wayland"

# Actualizar e instalar dependencias (Brave, drivers gráficos, audio, fuentes)
RUN dnf install -y \
    java-25-openjdk \
    mesa-libGL \
    mesa-libEGL \
    gtk3 \
    libX11 \
    libXrender \
    libXtst \
    libXi \
    libusb1 \
    && dnf clean all

COPY sparrowwallet-2.5.3-1.x86_64.rpm /tmp/

RUN dnf install -y /tmp/sparrowwallet-2.5.3-1.x86_64.rpm \
 && rm /tmp/*.rpm

# Crear usuario sin privilegios
RUN useradd -m -u 1000 cripto
USER cripto
WORKDIR /home/cripto

#ENV DBUS_SESSION_BUS_ADDRESS="autolaunch:"

ENTRYPOINT ["/opt/sparrowwallet/bin/Sparrow"]
