#!/bin/bash
set -e
cd /home/container

mkdir -p .ptero/tmp .ptero/bin

if [ "$(id -u)" = '0' ]; then
    if [ ! -f ".ptero/machine-id" ]; then
        echo ">>> Generating persistent machine-id..."
        cat /proc/sys/kernel/random/uuid > .ptero/machine-id
    fi
    cat .ptero/machine-id > /etc/machine-id

    chown -R container:container /home/container 2>/dev/null || true
    exec su container "$0" "$@"
fi

ARCH=$(uname -m)
BINARY=".ptero/bin/hytale-downloader-linux-amd64"

if [ ! -f "start.sh" ] || [ ! -f "Server/HytaleServer.jar" ]; then
    if [ ! -f "$BINARY" ]; then
        echo ">>> Downloading Hytale Downloader..."
        curl -sL -o dl.zip https://downloader.hytale.com/hytale-downloader.zip
        unzip -qo dl.zip && rm dl.zip
        mv hytale-downloader-linux-amd64 .ptero/bin/
        rm -f hytale-downloader-windows-amd64.exe QUICKSTART.md
        chmod +x "$BINARY"
    fi

    RUN_CMD="$BINARY"
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        echo ">>> Architecture ARM64 detected. Using QEMU static..."
        RUN_CMD="/usr/bin/qemu-x86_64-static $BINARY"
    fi

    echo ">>> Running server download process..."
    $RUN_CMD -download-path latest_release.zip
    unzip -qo latest_release.zip && rm latest_release.zip
fi

echo ">>> Cleaning up deployment artifacts..."
rm -f hytale-downloader-linux-amd64 hytale-downloader-windows-amd64.exe QUICKSTART.md

if [[ -f "/sync_plugins.sh" ]]; then
    echo ">>> Starting Plugin Synchronization..."
    /sync_plugins.sh
fi

echo ">>> Setting Java environment variables..."
export _JAVA_OPTIONS="-Djava.io.tmpdir=/home/container/.ptero/tmp"

echo ">>> Starting Hytale Server..."
exec ./start.sh \
     --bind 0.0.0.0:${SERVER_PORT:-5520} \
     --auth-mode authenticated
