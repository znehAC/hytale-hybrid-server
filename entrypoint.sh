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

if [ ! -f "$BINARY" ]; then
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

RUNNER=""
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "[system] arm64 detected. checking for qemu..."
    if [ -f "/usr/bin/qemu-x86_64-static" ]; then
        RUNNER="/usr/bin/qemu-x86_64-static"
    else
        RUNNER=$(which qemu-x86_64-static || which qemu-x86_64 || echo "")
    fi

    if [ -z "$RUNNER" ]; then
        echo "[error] qemu-x86_64-static not found. current path: $PATH"
        ls -l /usr/bin/qemu* || echo "no qemu binaries in /usr/bin"
        exit 1
    fi
    echo "[system] using runner: $RUNNER"
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
