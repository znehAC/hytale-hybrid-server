FROM eclipse-temurin:25-jdk

RUN apt-get update && apt-get install -y curl wget unzip ca-certificates gnupg && \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        echo "Installing box64 for ARM64 support..." && \
        wget https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list && \
        wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64.gpg && \
        apt-get update && \
        apt-get install -y box64; \
    fi && \
    rm -rf /var/lib/apt/lists/*

ENV USER=container HOME=/home/container
RUN useradd -m -d $HOME -s /bin/bash $USER

WORKDIR $HOME
COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER root
EXPOSE 5520/udp
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
