#!/bin/bash
set -e
cd /home/container

chown -R container:container /home/container
[[ ! -f /etc/machine-id ]] && echo "hytale_hybrid_stable_id" > /etc/machine-id 2>/dev/null

if [ "$(id -u)" = '0' ]; then
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"

if [ ! -f "$BINARY" ]; then
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

RUNNER=""
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "[system] arm64 detected. using qemu-x86_64 to avoid go-runtime segfaults..."
    RUNNER="qemu-x86_64-static"
fi

if [ ! -f "Assets.zip" ]; then
    echo "[info] syncing game files via qemu (this may be slow)..."
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
