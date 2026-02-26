#!/usr/bin/env bash
# Watches the Google Drive LogMem folder and auto-imports new notes.
# GDRIVE_INBOX is replaced by install.sh with the detected path.
# To update manually: edit GDRIVE_INBOX below.

GDRIVE_INBOX="GDRIVE_NOT_CONFIGURED/LogMem"
LOGMEM_FILES="$HOME/.logmem/files"
IMPORT_LOG="$HOME/.logmem/.sys/import.log"
KHOJ_PORT=9371

if [[ "$GDRIVE_INBOX" == "GDRIVE_NOT_CONFIGURED/LogMem" ]]; then
  echo "[$(date)] Google Drive not configured. Edit GDRIVE_INBOX in ~/.logmem/.sys/watcher.sh" >> "$IMPORT_LOG"
  exit 1
fi

echo "[$(date)] LogMem watcher started. Watching: $GDRIVE_INBOX" >> "$IMPORT_LOG"

/opt/homebrew/bin/fswatch -0 --event Created --event Updated --event MovedTo "$GDRIVE_INBOX" | while IFS= read -r -d '' FILEPATH; do

  FILENAME=$(basename "$FILEPATH")
  EXT="${FILENAME##*.}"

  # Only process .md and .txt files
  if [[ "$EXT" != "md" && "$EXT" != "txt" ]]; then
    continue
  fi

  # Wait briefly for file to finish writing
  sleep 1

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  DEST="$LOGMEM_FILES/mobile_${TIMESTAMP}_${FILENAME}"

  cp "$FILEPATH" "$DEST"
  echo "[$(date)] Imported: $FILENAME → $DEST" >> "$IMPORT_LOG"

  # Remove from inbox after import (may fail on Google Drive — that's OK)
  rm "$FILEPATH" 2>/dev/null || true

  # Trigger Khoj re-index if server is running
  curl -s -X POST "http://localhost:${KHOJ_PORT}/api/update?t=markdown" > /dev/null 2>&1 || true

done
