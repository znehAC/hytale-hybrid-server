#!/bin/bash
set -e
cd /home/container

echo "[system] ensuring correct permissions for /home/container..."
chown -R container:container /home/container

if [ "$(id -u)" = '0' ]; then
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"
RUNNER=""

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    RUNNER="box64"
fi

if [ ! -f "$BINARY" ]; then
    echo "[info] fetching official hytale cli..."
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

echo "[info] verifying license and initializing session..."
$RUNNER $BINARY -print-version || $RUNNER $BINARY

echo "[info] downloader version: $($RUNNER $BINARY -version)"
echo "[info] target game version: $($RUNNER $BINARY -print-version)"

if [ ! -f "Assets.zip" ]; then
    echo "[info] syncing game files (~3.3gb)..."
    $RUNNER $BINARY -download-path latest_release.zip -skip-update-check
    echo "[info] extracting hytale server files..."
    unzip -qo latest_release.zip && rm latest_release.zip
fi

echo "[start] launching hytale server (openjdk 25)..."
echo "[note] remember: the server itself requires a SECOND device auth on first boot."

java -XX:AOTCache=Server/HytaleServer.aot \
     -Xms2G -Xmx${SERVER_MEMORY:-4096}M \
     -jar Server/HytaleServer.jar \
     --assets Assets.zip \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
