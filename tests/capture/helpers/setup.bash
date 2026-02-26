#!/usr/bin/env bash
# Shared test helpers for memory capture bats tests
# Used by: text-capture.bats, screen-capture.bats, audio-capture.bats

# --- Test Environment Setup ---

# Create an isolated temp directory for each test
setup_test_env() {
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
  export MEMORIES_DIR="$TEST_TMPDIR/memories"
  export ASSETS_DIR="$MEMORIES_DIR/assets"
  mkdir -p "$ASSETS_DIR"

  # Create the .sys directory for scripts
  export SYS_DIR="$TEST_TMPDIR/sys"
  mkdir -p "$SYS_DIR"

  # Set SYSTEM_NAME for template-expanded scripts
  export SYSTEM_NAME="testmem"
}

# Cleanup temp directory after each test
teardown_test_env() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

# --- Mock Helpers ---

# Create a mock command that does nothing (exit 0)
mock_command() {
  local cmd_name="$1"
  local mock_dir="$TEST_TMPDIR/mock_bin"
  mkdir -p "$mock_dir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_dir/$cmd_name"
  chmod +x "$mock_dir/$cmd_name"
  export PATH="$mock_dir:$PATH"
}

# Create a mock command with custom output
mock_command_with_output() {
  local cmd_name="$1"
  local output="$2"
  local mock_dir="$TEST_TMPDIR/mock_bin"
  mkdir -p "$mock_dir"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$output" > "$mock_dir/$cmd_name"
  chmod +x "$mock_dir/$cmd_name"
  export PATH="$mock_dir:$PATH"
}

# Create a mock command that writes to a file (simulates sox recording)
mock_command_create_file() {
  local cmd_name="$1"
  local target_file="$2"
  local mock_dir="$TEST_TMPDIR/mock_bin"
  mkdir -p "$mock_dir"
  cat > "$mock_dir/$cmd_name" <<MOCK_EOF
#!/usr/bin/env bash
# Create the output file to simulate recording
echo "RIFF" > "$target_file"
# Run in foreground (caller backgrounds it)
sleep 60 &
echo \$!
wait
MOCK_EOF
  chmod +x "$mock_dir/$cmd_name"
  export PATH="$mock_dir:$PATH"
}

# Create a mock curl that silently succeeds (for reindex)
mock_reindex() {
  mock_command "curl"
}

# --- Fixture Generators ---

# Create a test PNG file with valid magic bytes
create_test_png() {
  local path="${1:-$TEST_TMPDIR/test_screenshot.png}"
  # PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A + minimal IHDR
  printf '\x89PNG\r\n\x1a\n' > "$path"
  # Add some content so it's non-zero
  dd if=/dev/urandom bs=100 count=1 >> "$path" 2>/dev/null
  echo "$path"
}

# Create a zero-size file
create_empty_file() {
  local path="${1:-$TEST_TMPDIR/empty.png}"
  touch "$path"
  echo "$path"
}

# Create a test WAV file with RIFF header
create_test_wav() {
  local path="${1:-$TEST_TMPDIR/test_audio.wav}"
  # RIFF/WAVE header
  printf 'RIFF\x00\x00\x00\x00WAVEfmt ' > "$path"
  dd if=/dev/urandom bs=1000 count=1 >> "$path" 2>/dev/null
  echo "$path"
}

# --- Assertion Helpers ---

# Assert file exists and is non-empty
assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "FAIL: File does not exist: $path" >&2
    return 1
  }
  [[ -s "$path" ]] || {
    echo "FAIL: File is empty: $path" >&2
    return 1
  }
}

# Assert file matches naming pattern
assert_file_matches_pattern() {
  local dir="$1"
  local pattern="$2"
  local count
  count=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$count" -gt 0 ]] || {
    echo "FAIL: No file matching pattern '$pattern' in $dir" >&2
    return 1
  }
}

# Assert YAML front-matter field exists with expected value
assert_frontmatter_field() {
  local file="$1"
  local field="$2"
  local expected="$3"
  local value
  # Extract value between --- markers
  value=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}: *//")
  if [[ -n "$expected" ]]; then
    [[ "$value" == "$expected" ]] || {
      echo "FAIL: Front-matter field '$field' expected '$expected', got '$value'" >&2
      return 1
    }
  else
    [[ -n "$value" ]] || {
      echo "FAIL: Front-matter field '$field' not found" >&2
      return 1
    }
  fi
}

# Assert YAML front-matter is valid (has opening and closing ---)
assert_valid_frontmatter() {
  local file="$1"
  local fm_count
  fm_count=$(grep -c '^---$' "$file")
  [[ "$fm_count" -ge 2 ]] || {
    echo "FAIL: Invalid YAML front-matter (expected at least 2 '---' markers)" >&2
    return 1
  }
}

# Assert file does not exist
assert_file_not_exists() {
  local path="$1"
  [[ ! -f "$path" ]] || {
    echo "FAIL: File should not exist: $path" >&2
    return 1
  }
}

# Assert directory exists
assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || {
    echo "FAIL: Directory does not exist: $path" >&2
    return 1
  }
}
