#!/bin/bash
set -e
cd /home/container

if [ "$(id -u)" = '0' ]; then
    echo "[system] root detected. adjusting permissions..."
    chown -R container:container /home/container || echo "[warn] chown failed"
    [[ ! -f /etc/machine-id ]] && echo "hytale_hybrid_stable_id" > /etc/machine-id 2>/dev/null
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"

if [ ! -f "$BINARY" ]; then
    echo "[info] fetching official hytale cli..."
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

RUNNER=""
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "[system] arm64 detected. using box64 in interpreter mode for go binary..."
    export BOX64_DYNAREC=0
    export BOX64_LOG=1
    RUNNER="box64"
fi

if [ ! -f "Assets.zip" ]; then
    echo "[info] syncing game files..."
    $RUNNER $BINARY -download-path latest_release.zip -skip-update-check
    unzip -qo latest_release.zip && rm latest_release.zip
fi

echo "[start] launching native hytale server..."
unset BOX64_DYNAREC
java -XX:AOTCache=Server/HytaleServer.aot \
     -Xms2G -Xmx${SERVER_MEMORY:-4096}M \
     -jar Server/HytaleServer.jar \
     --assets Assets.zip \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
