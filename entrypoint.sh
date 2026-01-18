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
    echo "[info] fetching downloader..."
    curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
    unzip -qo dl.zip && rm dl.zip
    chmod +x "$BINARY"
fi

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    if ! $BINARY --help &>/dev/null 2>&1; then
        if [ -x /usr/bin/qemu-x86_64-static ]; then
            echo "[system] ARM64 detected, using QEMU for x86_64 emulation"
            BINARY="/usr/bin/qemu-x86_64-static $BINARY"
        else
            echo "[error] ARM64 detected but QEMU not available!"
            exit 1
        fi
    else
        echo "[system] ARM64 with binfmt support detected"
    fi
fi

echo "[info] checking for updates..."
$BINARY -download-path latest_release.zip
if [ -f "latest_release.zip" ]; then
    echo "[info] extracting update..."
    unzip -qo latest_release.zip && rm latest_release.zip
fi

[ ! -s "config.json" ] && echo '{}' > config.json

JAVA_ARGS="-Xms2G -Xmx${SERVER_MEMORY:-4096}M"
[[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]] && JAVA_ARGS="-XX:AOTCache=Server/HytaleServer.aot $JAVA_ARGS"

echo "[start] launching server..."
java $JAVA_ARGS \
     -jar Server/HytaleServer.jar \
     --assets Assets.zip \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
