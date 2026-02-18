#!/bin/bash

MODS_FILE="mods.list"
STATE_FILE=".ptero_mods.state"
MODS_DIR="Server/mods"
API_KEY="${CF_API_KEY}"

[[ ! -f "$MODS_FILE" ]] && exit 0
[[ -z "$API_KEY" ]] && { echo "CF_API_KEY unset"; exit 1; }

mkdir -p "$MODS_DIR"
touch "$STATE_FILE"

echo ">>> Verifying plugins via CurseForge API..."

while IFS=, read -r SLUG ID; do
    # Sanitize
    SLUG=$(echo "$SLUG" | xargs)
    ID=$(echo "$ID" | xargs)

    # Fetch mod metadata
    RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" \
        "https://api.curseforge.com/v1/mods/$ID")
    
    LATEST_FILE_ID=$(echo "$RES" | jq -r '.data.mainFileId // .data.latestFiles[0].id')
    CURRENT_FILE_ID=$(grep "^$ID:" "$STATE_FILE" | cut -d: -f2)

    if [[ "$LATEST_FILE_ID" != "$CURRENT_FILE_ID" ]]; then
        echo "[UPDATE] $SLUG detected..."
        
        # Get download URL
        FILE_RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" \
            "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID")
        
        URL=$(echo "$FILE_RES" | jq -r '.data.downloadUrl')
        NAME=$(echo "$FILE_RES" | jq -r '.data.fileName')

        if [[ "$URL" == "null" ]]; then
            URL=$(curl -sL -H "x-api-key: $API_KEY" \
                "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID/download-url" | jq -r '.data')
        fi

        # Atomic cleanup and download
        find "$MODS_DIR" -name "${SLUG}*.jar" -delete
        curl -sL -o "$MODS_DIR/$NAME" "$URL"
        
        # Persist state
        sed -i "/^$ID:/d" "$STATE_FILE"
        echo "$ID:$LATEST_FILE_ID" >> "$STATE_FILE"
        echo "[DONE] $NAME downloaded."
    fi
done < "$MODS_FILE"
