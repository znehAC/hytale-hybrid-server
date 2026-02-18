#!/bin/bash
MODS_FILE="mods.list"
STATE_FILE=".ptero/mods.state"
MODS_DIR="mods"
API_KEY="${CF_API_KEY}"

if [[ ! -f "$MODS_FILE" ]]; then
    echo "!!! mods.list not found. Skipping plugin sync."
    exit 0
fi

if [[ -z "$API_KEY" ]]; then
    echo "!!! CF_API_KEY is not set. Cannot sync plugins."
    exit 1
fi

mkdir -p "$MODS_DIR" ".ptero"
touch "$STATE_FILE"

while IFS=, read -r SLUG ID; do
    SLUG=$(echo "$SLUG" | xargs)
    ID=$(echo "$ID" | xargs)

    echo ">>> Checking mod: $SLUG ($ID)"
    
    RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" "https://api.curseforge.com/v1/mods/$ID")
    LATEST_FILE_ID=$(echo "$RES" | jq -r '.data.mainFileId // .data.latestFiles[0].id')
    CURRENT_STATE_ID=$(grep "^$ID:" "$STATE_FILE" | cut -d: -f2)
    FILE_EXISTS=$(find "$MODS_DIR" -name "*${SLUG}*.jar" | head -n 1)

    if [[ "$LATEST_FILE_ID" != "$CURRENT_STATE_ID" ]] || [[ -z "$FILE_EXISTS" ]]; then
        echo ">>> Update or missing file detected for $SLUG. Fetching file details..."
        
        FILE_RES=$(curl -sL -H "x-api-key: $API_KEY" -H "Accept: application/json" "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID")
        URL=$(echo "$FILE_RES" | jq -r '.data.downloadUrl')
        NAME=$(echo "$FILE_RES" | jq -r '.data.fileName')

        if [[ "$URL" == "null" ]]; then
            echo ">>> Download URL is null. Requesting direct download link..."
            URL=$(curl -sL -H "x-api-key: $API_KEY" "https://api.curseforge.com/v1/mods/$ID/files/$LATEST_FILE_ID/download-url" | jq -r '.data')
        fi

        echo ">>> Removing old versions of $SLUG..."
        find "$MODS_DIR" -name "*${SLUG}*.jar" -delete
        
        echo ">>> Downloading $NAME..."
        curl -sL -o "$MODS_DIR/$NAME" "$URL"
        
        echo ">>> Updating state for $ID..."
        sed -i "/^$ID:/d" "$STATE_FILE"
        echo "$ID:$LATEST_FILE_ID" >> "$STATE_FILE"
    else
        echo ">>> $SLUG is up to date."
    fi
done < "$MODS_FILE"
