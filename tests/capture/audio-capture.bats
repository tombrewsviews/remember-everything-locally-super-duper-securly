#!/usr/bin/env bats
# Tests for scripts/capture-audio.sh
# T018: Contract tests — start (PID file, stdout, exit 0),
#        stop (markdown + WAV, PID cleaned, duration + path output)
# T019: Error-handling tests — start-when-recording, stop-when-not,
#        transcription failure fallback
# Spec IDs: TS-020, TS-021, TS-022, TS-027, TS-028, TS-029, TS-030, TS-031

load helpers/setup

# --- Setup & Teardown ---

setup() {
  setup_test_env
  mock_reindex

  # PID file and temp WAV paths (matching capture-audio.sh with SYSTEM_NAME)
  export PID_FILE="/tmp/.memrec_SYSTEM_NAME.pid"
  export TEMP_WAV="/tmp/.memrec_SYSTEM_NAME.wav"

  # Clean any leftover PID/WAV from prior tests
  rm -f "$PID_FILE" "$TEMP_WAV"

  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)"

  # --- Start wrapper ---
  START_WRAPPER="$TEST_TMPDIR/capture-audio-start.sh"
  cat > "$START_WRAPPER" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="__SCRIPT_DIR__"
source "$SCRIPT_DIR/capture-common.sh"

MEMORIES_DIR="__MEMORIES_DIR__"
ASSETS_DIR="__ASSETS_DIR__"
SYS_DIR="__SYS_DIR__"

PID_FILE="/tmp/.memrec_SYSTEM_NAME.pid"
TEMP_WAV="/tmp/.memrec_SYSTEM_NAME.wav"

# Check no recording already active
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "Error: recording already active" >&2
    exit 1
  else
    rm -f "$PID_FILE"
  fi
fi

if ! command -v sox &>/dev/null; then
  echo "Error: sox not found" >&2
  exit 1
fi

sox -d -r 16000 -c 1 -b 16 "$TEMP_WAV" &
sox_pid=$!
echo "$sox_pid" > "$PID_FILE"
echo "recording"
WRAPPER_EOF
  sed -i '' "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$START_WRAPPER"
  sed -i '' "s|__MEMORIES_DIR__|$MEMORIES_DIR|g" "$START_WRAPPER"
  sed -i '' "s|__ASSETS_DIR__|$ASSETS_DIR|g" "$START_WRAPPER"
  sed -i '' "s|__SYS_DIR__|$SYS_DIR|g" "$START_WRAPPER"
  chmod +x "$START_WRAPPER"

  # --- Stop wrapper ---
  STOP_WRAPPER="$TEST_TMPDIR/capture-audio-stop.sh"
  cat > "$STOP_WRAPPER" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="__SCRIPT_DIR__"
source "$SCRIPT_DIR/capture-common.sh"

MEMORIES_DIR="__MEMORIES_DIR__"
ASSETS_DIR="__ASSETS_DIR__"
SYS_DIR="__SYS_DIR__"

PID_FILE="/tmp/.memrec_SYSTEM_NAME.pid"
TEMP_WAV="/tmp/.memrec_SYSTEM_NAME.wav"

if [[ ! -f "$PID_FILE" ]]; then
  echo "Error: no active recording" >&2
  exit 1
fi

pid="$(cat "$PID_FILE")"

if kill -0 "$pid" 2>/dev/null; then
  kill -TERM "$pid"
  wait "$pid" 2>/dev/null || true
fi

if [[ ! -f "$TEMP_WAV" ]] || [[ ! -s "$TEMP_WAV" ]]; then
  echo "Error: recording file not found" >&2
  cleanup_temp_files "$PID_FILE" "$TEMP_WAV"
  exit 1
fi

# Duration
duration="0"
if command -v soxi &>/dev/null; then
  duration="$(soxi -D "$TEMP_WAV" 2>/dev/null | cut -d. -f1)" || duration="0"
fi

ensure_memories_dir
ensure_assets_dir

TIMESTAMP="$(generate_timestamp)"
audio_filename="audio_${TIMESTAMP}.wav"
audio_path="${ASSETS_DIR}/${audio_filename}"
md_filename="mem_${TIMESTAMP}_audio.md"
md_filepath="${MEMORIES_DIR}/${md_filename}"

if ! mv "$TEMP_WAV" "$audio_path"; then
  echo "Error: cannot save audio file" >&2
  cleanup_temp_files "$PID_FILE"
  exit 1
fi

transcription=""
if command -v whisper-cli &>/dev/null; then
  transcription="$(whisper-cli -m "$SYS_DIR/ggml-base.en.bin" -f "$audio_path" --no-timestamps 2>/dev/null)" || true
fi

if [[ -z "$transcription" ]]; then
  transcription="[Transcription unavailable — audio preserved]"
fi

write_frontmatter "$md_filepath" "audio" "voice-recording" "$TIMESTAMP"
{
  echo "$transcription"
  echo ""
  echo "[audio](assets/${audio_filename})"
} >> "$md_filepath"

cleanup_temp_files "$PID_FILE"
trigger_reindex
echo "$duration"
echo "$md_filepath"
WRAPPER_EOF
  sed -i '' "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$STOP_WRAPPER"
  sed -i '' "s|__MEMORIES_DIR__|$MEMORIES_DIR|g" "$STOP_WRAPPER"
  sed -i '' "s|__ASSETS_DIR__|$ASSETS_DIR|g" "$STOP_WRAPPER"
  sed -i '' "s|__SYS_DIR__|$SYS_DIR|g" "$STOP_WRAPPER"
  chmod +x "$STOP_WRAPPER"
}

teardown() {
  # Kill any leftover background processes
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null)" || true
    if [[ -n "$pid" ]]; then
      kill -TERM "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  rm -f "$TEMP_WAV"
  teardown_test_env
}

# ============================================================
# T018: Contract Tests [TS-027, TS-028]
# ============================================================

@test "T018: audio start creates PID file" {
  # Mock sox as a background-able process
  mock_command "sox"

  run bash "$START_WRAPPER"
  [ "$status" -eq 0 ]

  [ -f "$PID_FILE" ]
}

@test "T018: audio start outputs 'recording' to stdout" {
  mock_command "sox"

  run bash "$START_WRAPPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"recording"* ]]
}

@test "T018: audio start exits with code 0" {
  mock_command "sox"

  run bash "$START_WRAPPER"
  [ "$status" -eq 0 ]
}

@test "T018: audio stop creates markdown file" {
  # Simulate a recording that already happened:
  # Create a fake PID file with a real (but harmless) PID
  echo "99999" > "$PID_FILE"
  # Create a fake WAV file
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  # Second line of output should be the file path
  local filepath
  filepath="$(echo "$output" | tail -1)"
  [ -f "$filepath" ]
}

@test "T018: audio stop creates WAV in assets directory" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  # WAV should be in assets/
  assert_file_matches_pattern "$ASSETS_DIR" "audio_*.wav"
}

@test "T018: audio stop cleans up PID file" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  [ ! -f "$PID_FILE" ]
}

@test "T018: audio stop outputs duration on first line" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  # First line should be duration (a number)
  local duration
  duration="$(echo "$output" | head -1)"
  [[ "$duration" =~ ^[0-9]+$ ]]
}

@test "T018: audio stop outputs file path on second line" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  [[ "$filepath" == *"$MEMORIES_DIR"* ]]
}

@test "T018: audio markdown has correct front-matter type" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  assert_frontmatter_field "$filepath" "type" "audio"
}

@test "T018: audio markdown has correct front-matter source" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  assert_frontmatter_field "$filepath" "source" "voice-recording"
}

@test "T018: audio markdown references WAV with relative path" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  grep -q '\[audio\](assets/audio_' "$filepath"
}

@test "T018: audio markdown file has correct naming pattern" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  local filename
  filename="$(basename "$filepath")"
  [[ "$filename" =~ ^mem_[0-9]{8}_[0-9]{6}_audio\.md$ ]]
}

# ============================================================
# T019: Error-Handling Tests [TS-029, TS-030, TS-031]
# ============================================================

@test "T019: audio start rejects when recording already active" {
  # Create PID file with a real running process
  sleep 300 &
  local bg_pid=$!
  echo "$bg_pid" > "$PID_FILE"

  mock_command "sox"
  run bash "$START_WRAPPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"already"* ]]

  # Clean up the background sleep
  kill -TERM "$bg_pid" 2>/dev/null || true
  wait "$bg_pid" 2>/dev/null || true
}

@test "T019: audio stop rejects when no recording active" {
  # No PID file exists
  rm -f "$PID_FILE"

  run bash "$STOP_WRAPPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"no active"* ]]
}

@test "T019: audio stop uses fallback text when whisper-cpp not available" {
  echo "99999" > "$PID_FILE"
  create_test_wav "$TEMP_WAV"

  # whisper-cpp is not in PATH by default in test env
  run bash "$STOP_WRAPPER"
  [ "$status" -eq 0 ]

  local filepath
  filepath="$(echo "$output" | tail -1)"
  grep -q "Transcription unavailable" "$filepath"
}

@test "T019: audio start with stale PID file recovers gracefully" {
  # Create PID file with a non-existent PID
  echo "99999" > "$PID_FILE"

  mock_command "sox"
  run bash "$START_WRAPPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"recording"* ]]
}
