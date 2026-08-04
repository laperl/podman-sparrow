FROM registry.fedoraproject.org/fedora:latest

LABEL maintainer="Jaume"
LABEL description="Sparrow Wallet en Fedora, rootless, con rendering por software"

RUN dnf install -y \
        java-25-openjdk \
        mesa-libGL \
        gtk3 \
        libX11 \
        libXrender \
        libXtst \
        libXi \
        libusb1 \
        curl \
        gnupg2 \
        sha256sum \
    && dnf clean all

# El RPM se inyecta en build-time mediante --build-context o build.sh
ARG RPM_FILE=sparrowwallet-2.5.3-1.x86_64.rpm
COPY ${RPM_FILE} /tmp/
RUN dnf install -y /tmp/*.rpm && rm -f /tmp/*.rpm

RUN useradd -m -u 1000 cripto
USER cripto
WORKDIR /home/cripto

ENTRYPOINT ["/opt/sparrowwallet/bin/Sparrow"]
