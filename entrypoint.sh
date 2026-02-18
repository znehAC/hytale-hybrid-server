#!/bin/bash
set -e
cd /home/container

if [ "$(id -u)" = '0' ]; then
    chown -R container:container /home/container 2>/dev/null || true
    [[ ! -f /etc/machine-id ]] && echo "hytale_hybrid_stable_id" > /etc/machine-id 2>/dev/null || true
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"

if [ ! -f "start.sh" ] || [ ! -f "Server/HytaleServer.jar" ]; then
    if [ ! -f "$BINARY" ]; then
        curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
        unzip -qo dl.zip && rm dl.zip
        chmod +x "$BINARY"
    fi

    RUN_CMD="$BINARY"
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        if ! $BINARY --help &>/dev/null 2>&1; then
            if [ -x /usr/bin/qemu-x86_64-static ]; then
                RUN_CMD="/usr/bin/qemu-x86_64-static $BINARY"
            else
                exit 1
            fi
        fi
    fi

    $RUN_CMD -download-path latest_release.zip
    unzip -qo latest_release.zip && rm latest_release.zip
fi

[ ! -s "config.json" ] && echo '{}' > config.json

if [ -f "start.sh" ]; then
    chmod +x start.sh
fi

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    rm -f Server/HytaleServer.aot
fi

export _JAVA_OPTIONS="-Djava.io.tmpdir=/home/container"

exec ./start.sh \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
