FROM multiarch/qemu-user-static:latest AS qemu

FROM eclipse-temurin:25-jdk

COPY --from=qemu /usr/bin/qemu-x86_64-static /usr/bin/qemu-x86_64-static

RUN apt-get update && apt-get install -y \
    curl wget unzip ca-certificates gnupg && \
    rm -rf /var/lib/apt/lists/*

ENV USER=container HOME=/home/container
RUN useradd -m -d $HOME -s /bin/bash $USER

WORKDIR $HOME
COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER root
EXPOSE 5520/udp
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
