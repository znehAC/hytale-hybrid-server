#!/bin/bash
set -e
cd /home/container

if [ "$(id -u)" = '0' ]; then
    echo "[system] root detected. attempting permission/identity fixes..."
    chown -R container:container /home/container 2>/dev/null || true
    
    if [ ! -f /etc/machine-id ]; then
        echo "hytale_hybrid_stable_id" > /etc/machine-id 2>/dev/null || true
    fi

    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"
RUNNER=""

if [ ! -f "$BINARY" ]; then
    echo "[info] fetching official hytale cli..."
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "[system] arm64 detected. using qemu-x86_64-static for the downloader..."
    RUNNER="qemu-x86_64-static"
fi

if [ ! -f "Assets.zip" ]; then
    echo "[info] syncing game files via qemu..."
    $RUNNER $BINARY -download-path latest_release.zip -skip-update-check
    unzip -qo latest_release.zip && rm latest_release.zip
fi

echo "[start] launching native hytale server..."
java -XX:AOTCache=Server/HytaleServer.aot \
     -Xms2G -Xmx${SERVER_MEMORY:-4096}M \
     -jar Server/HytaleServer.jar \
     --assets Assets.zip \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
