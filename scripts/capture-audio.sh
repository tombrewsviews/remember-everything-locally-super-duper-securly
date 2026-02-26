#!/usr/bin/env bash
# Start/stop audio recording and transcribe locally
# Usage: capture-audio.sh start | capture-audio.sh stop
# SYSTEM_NAME is replaced by install.sh via sed
set -e

# shellcheck source=capture-common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/capture-common.sh"

# --- Constants ---

PID_FILE="/tmp/.memrec_SYSTEM_NAME.pid"
TEMP_WAV="/tmp/.memrec_SYSTEM_NAME.wav"

# --- Start Recording ---

do_start() {
  # Check no recording already active
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "Error: recording already active" >&2
      exit 1
    else
      # Stale PID file — clean up
      rm -f "$PID_FILE"
    fi
  fi

  # Check sox is available
  if ! command -v sox &>/dev/null; then
    echo "Error: sox not found" >&2
    exit 1
  fi

  # Start recording in background
  sox -d -r 16000 -c 1 -b 16 "$TEMP_WAV" &
  local sox_pid=$!
  echo "$sox_pid" > "$PID_FILE"

  echo "recording"
}

# --- Stop Recording ---

do_stop() {
  # Check recording is active
  if [[ ! -f "$PID_FILE" ]]; then
    echo "Error: no active recording" >&2
    exit 1
  fi

  local pid
  pid="$(cat "$PID_FILE")"

  # Stop sox gracefully
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid"
    wait "$pid" 2>/dev/null || true
  fi

  # Validate WAV file exists
  if [[ ! -f "$TEMP_WAV" ]] || [[ ! -s "$TEMP_WAV" ]]; then
    echo "Error: recording file not found" >&2
    cleanup_temp_files "$PID_FILE" "$TEMP_WAV"
    exit 1
  fi

  # Calculate duration from WAV file (soxi reports seconds)
  local duration
  if command -v soxi &>/dev/null; then
    duration="$(soxi -D "$TEMP_WAV" 2>/dev/null | cut -d. -f1)" || duration="0"
  else
    duration="0"
  fi

  ensure_memories_dir
  ensure_assets_dir

  TIMESTAMP="$(generate_timestamp)"
  local audio_filename="audio_${TIMESTAMP}.wav"
  local audio_path="${ASSETS_DIR}/${audio_filename}"
  local md_filename="mem_${TIMESTAMP}_audio.md"
  local md_filepath="${MEMORIES_DIR}/${md_filename}"

  # Move WAV to assets
  if ! mv "$TEMP_WAV" "$audio_path"; then
    echo "Error: cannot save audio file" >&2
    cleanup_temp_files "$PID_FILE"
    exit 1
  fi

  # Run whisper-cpp transcription
  local transcription=""
  if command -v whisper-cpp &>/dev/null; then
    transcription="$(whisper-cpp -m "$SYS_DIR/ggml-base.en.bin" -f "$audio_path" --no-timestamps 2>/dev/null)" || true
  fi

  # Fallback text if transcription failed or empty
  if [[ -z "$transcription" ]]; then
    transcription="[Transcription unavailable — audio preserved]"
  fi

  # Write markdown with YAML front-matter
  write_frontmatter "$md_filepath" "audio" "voice-recording" "$TIMESTAMP"

  # Add transcription body and audio reference
  {
    echo "$transcription"
    echo ""
    echo "[audio](assets/${audio_filename})"
  } >> "$md_filepath"

  # Clean up PID file
  cleanup_temp_files "$PID_FILE"

  # Trigger async re-index (best-effort)
  trigger_reindex

  # Output duration and file path (two lines)
  echo "$duration"
  echo "$md_filepath"
}

# --- Subcommand Routing ---

ACTION="${1:-}"

case "$ACTION" in
  start)
    do_start
    ;;
  stop)
    do_stop
    ;;
  *)
    echo "Usage: capture-audio.sh start|stop" >&2
    exit 1
    ;;
esac
