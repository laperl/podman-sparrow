FROM registry.fedoraproject.org/fedora:latest

LABEL maintainer="Jaume"
LABEL description="Sparrow Wallet rootless con rendering por software"

# Solo lo imprescindible. Sin gnupg2, sin curl, sin sha256sum.
RUN dnf install -y --setopt=install_weak_deps=False \
        java-25-openjdk \
        mesa-libGL \
        gtk3 \
        libX11 \
        libXrender \
        libXtst \
        libXi \
        libusb1 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# El RPM se inyecta desde el host (verificado previamente)
ARG RPM_FILE=sparrowwallet-2.5.3-1.x86_64.rpm
COPY ${RPM_FILE} /tmp/
RUN dnf install -y --setopt=install_weak_deps=False /tmp/${RPM_FILE} \
    && rm -f /tmp/*.rpm \
    && dnf clean all

RUN useradd -m -u 1000 cripto
USER cripto
WORKDIR /home/cripto

ENTRYPOINT ["/opt/sparrowwallet/bin/Sparrow"]
