#!/bin/bash
MODS_FILE="mods.list"
STATE_FILE=".ptero/mods.state"
MODS_DIR="Server/mods"
API_KEY="${CF_API_KEY}"

[[ ! -f "$MODS_FILE" ]] && echo "!!! mods.list missing." && exit 0
[[ -z "$API_KEY" ]] && echo "!!! CF_API_KEY unset." && exit 1

mkdir -p "$MODS_DIR" ".ptero"
touch "$STATE_FILE"

while IFS=, read -r SLUG ID; do
    SLUG=$(echo "$SLUG" | xargs)
    ID=$(echo "$ID" | xargs)

    STATE_ENTRY=$(grep "^$ID:" "$STATE_FILE")
    CURRENT_STATE_ID=$(echo "$STATE_ENTRY" | cut -d: -f2)
    CURRENT_FILENAME=$(echo "$STATE_ENTRY" | cut -d: -f3)

    echo ">>> Checking: $SLUG ($ID)"

    RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" "https://api.curseforge.com/v1/mods/$ID")
    LATEST_FILE_ID=$(echo "$RES" | jq -r '.data.mainFileId // .data.latestFiles[0].id')

    if [[ "$LATEST_FILE_ID" != "$CURRENT_STATE_ID" ]] || [[ -n "$CURRENT_FILENAME" && ! -f "$MODS_DIR/$CURRENT_FILENAME" ]]; then
        echo ">>> Update required for $SLUG ($CURRENT_STATE_ID -> $LATEST_FILE_ID)..."

        FILE_RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID")
        URL=$(echo "$FILE_RES" | jq -r '.data.downloadUrl')
        NAME=$(echo "$FILE_RES" | jq -r '.data.fileName')

        if [[ "$URL" == "null" ]]; then
            URL=$(curl -sL -H "x-api-key: $API_KEY" "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID/download-url" | jq -r '.data')
        fi

        if [[ -n "$CURRENT_FILENAME" && -f "$MODS_DIR/$CURRENT_FILENAME" ]]; then
            echo ">>> Removing tracked version: $CURRENT_FILENAME"
            rm -f "$MODS_DIR/$CURRENT_FILENAME"
        fi

        if [[ -z "$CURRENT_FILENAME" ]]; then
            echo ">>> Cleaning up legacy files for pattern: *${SLUG}*..."
            find "$MODS_DIR" -maxdepth 1 -type f -iname "*${SLUG}*.jar" -not -name "$NAME" -delete
        fi

        echo ">>> Downloading $NAME..."
        curl -sL -o "$MODS_DIR/$NAME" "$URL"

        sed -i "/^$ID:/d" "$STATE_FILE"
        echo "$ID:$LATEST_FILE_ID:$NAME" >> "$STATE_FILE"
    else
        echo ">>> $SLUG is up to date."
    fi
done < "$MODS_FILE"
