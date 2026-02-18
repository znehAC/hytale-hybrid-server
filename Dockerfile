FROM eclipse-temurin:25-jdk

RUN apt-get update && apt-get install -y \
    curl wget unzip ca-certificates gnupg jq \
    qemu-user-static && \
    rm -rf /var/lib/apt/lists/*

ENV USER=container HOME=/home/container
RUN useradd -m -d $HOME -s /bin/bash $USER

WORKDIR $HOME
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY --chmod=755 sync_plugins.sh /sync_plugins.sh

USER root
EXPOSE 5520/udp
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
