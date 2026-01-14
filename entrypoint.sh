#!/bin/bash
set -e
cd /home/container

chown -R container:container /home/container
[[ ! -f /etc/machine-id ]] && echo "hytale_hybrid_stable_id" > /etc/machine-id

if [ "$(id -u)" = '0' ]; then
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY="./hytale-downloader-linux-amd64"
RUNNER=""
[[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && RUNNER="box64"

if [ ! -f "$BINARY" ]; then
    echo "[info] fetching official hytale cli..."
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

echo "[info] verifying license..."
AUTH_CHECK=$($RUNNER $BINARY -print-version 2>&1 || true)

if echo "$AUTH_CHECK" | grep -q "403 Forbidden"; then
    echo "[error] no license found. visit hytale.com/shop"
    exit 1
elif echo "$AUTH_CHECK" | grep -q "authenticate"; then
    echo "[auth] follow the link to authorize the downloader:"
    $RUNNER $BINARY -print-version
fi

if [ ! -f "Assets.zip" ]; then
    echo "[info] syncing game files (~3.3gb)..."
    $RUNNER $BINARY -download-path latest_release.zip -skip-update-check
    unzip -qo latest_release.zip && rm latest_release.zip
fi

echo "[start] launching native hytale server (openjdk 25)..."
java -XX:AOTCache=Server/HytaleServer.aot \
     -Xms2G -Xmx${SERVER_MEMORY:-4096}M \
     -jar Server/HytaleServer.jar \
     --assets Assets.zip \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
