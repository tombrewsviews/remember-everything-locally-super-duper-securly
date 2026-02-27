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
    echo "Error: sox not found — install with: brew install sox" >&2
    exit 1
  fi

  # Remove any leftover temp wav
  rm -f "$TEMP_WAV"

  # Start recording with nohup so sox survives the parent shell exiting.
  # Redirect sox stderr to /dev/null to avoid noise.
  nohup sox -d -r 16000 -c 1 -b 16 "$TEMP_WAV" > /dev/null 2>&1 &
  local sox_pid=$!

  # Brief sleep to verify sox actually started
  sleep 0.3
  if ! kill -0 "$sox_pid" 2>/dev/null; then
    echo "Error: sox failed to start recording" >&2
    exit 1
  fi

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

  # Stop sox gracefully — send SIGINT first (sox handles it to finalize WAV headers)
  if kill -0 "$pid" 2>/dev/null; then
    kill -INT "$pid" 2>/dev/null || true
    # Wait for sox to write WAV headers and exit (up to 3 seconds)
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 30 ]]; do
      sleep 0.1
      waited=$((waited + 1))
    done
    # Force kill if still alive
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
      sleep 0.2
    fi
  fi

  # Clean up PID file
  rm -f "$PID_FILE"

  # Validate WAV file exists and has content
  if [[ ! -f "$TEMP_WAV" ]] || [[ ! -s "$TEMP_WAV" ]]; then
    echo "Error: recording file not found or empty" >&2
    rm -f "$TEMP_WAV"
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
    exit 1
  fi

  # Run whisper transcription (binary is called whisper-cli, installed via brew whisper-cpp)
  # Model path: $SYS_DIR/ggml-base.en.bin (SYS_DIR = ~/.SYSTEM_NAME/.sys)
  local transcription=""
  if command -v whisper-cli &>/dev/null; then
    local model_path="$SYS_DIR/ggml-base.en.bin"
    if [[ -f "$model_path" ]]; then
      transcription="$(whisper-cli -m "$model_path" -f "$audio_path" --no-timestamps 2>/dev/null)" || true
    fi
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
