# Quickstart: Memory Capture System

**Feature**: 001-memory-capture
**Date**: 2026-02-27

## Prerequisites

- macOS (tested on macOS 14+, macOS 26 Tahoe)
- Homebrew installed
- Existing system install (run `install.sh` first)

## Quick Test Scenarios

### 1. Text Capture (FR-001, FR-002, FR-003, SC-001)

```bash
# Verify capture-text.sh works standalone
echo "Test memory content" | xargs ~/.SYSTEM_NAME/.sys/capture-text.sh

# Verify file was created
ls -la ~/.SYSTEM_NAME/files/memories/mem_*_text.md | tail -1

# Verify front-matter
head -10 ~/.SYSTEM_NAME/files/memories/mem_*_text.md | tail -1
```

Expected: A timestamped markdown file with YAML front-matter containing `type: text`.

### 2. Screenshot Capture (FR-004, FR-005, FR-006, SC-002)

**Via Hammerspoon (recommended)**:
```bash
# Press Ctrl+Opt+S — dark overlay appears
# Click and drag to select a region — blue rectangle shows selection
# On release: dialog appears for optional annotation
# Click Save — screenshot saved

# Verify files
ls -la ~/.SYSTEM_NAME/files/memories/mem_*_screenshot.md | tail -1
ls -la ~/.SYSTEM_NAME/files/memories/assets/scr_*.png | tail -1
```

**Via shell script only (backend test)**:
```bash
# Create a test PNG manually (e.g., from any image file)
cp /path/to/any/image.png /tmp/.memcap_test.png

# Run capture-screen.sh
~/.SYSTEM_NAME/.sys/capture-screen.sh /tmp/.memcap_test.png "Test annotation"

# Verify files
ls -la ~/.SYSTEM_NAME/files/memories/mem_*_screenshot.md | tail -1
ls -la ~/.SYSTEM_NAME/files/memories/assets/scr_*.png | tail -1
```

Expected: A markdown file referencing the PNG in assets/, with annotation in front-matter.

**Note**: The `screencapture` CLI tool is NOT used. Screenshot capture uses Hammerspoon's native `hs.screen:snapshot(rect)` API, which requires Screen Recording permission granted directly to Hammerspoon (not to child processes). This avoids permission inheritance issues on macOS 15+ / macOS 26.

### 3. Audio Capture (FR-008, FR-009, FR-010, SC-003)

```bash
# Start recording
~/.SYSTEM_NAME/.sys/capture-audio.sh start

# Wait 5 seconds (speak something)
sleep 5

# Stop recording
~/.SYSTEM_NAME/.sys/capture-audio.sh stop

# Verify files
ls -la ~/.SYSTEM_NAME/files/memories/mem_*_audio.md | tail -1
ls -la ~/.SYSTEM_NAME/files/memories/assets/audio_*.wav | tail -1

# Check transcription content
cat ~/.SYSTEM_NAME/files/memories/mem_*_audio.md | tail -1
```

Expected: A markdown file with transcribed text and WAV reference in assets/.

### 4. Stealth Verification (FR-014, SC-006)

```bash
# Verify no dock icon
defaults read org.hammerspoon.Hammerspoon MJShowDockIconKey
# Expected: 0

# Verify Spotlight exclusion
mdls ~/.SYSTEM_NAME/files/memories/.metadata_never_index
# Expected: file exists

# Verify no menu bar item (when not recording)
# Visual check — no Hammerspoon icon in menu bar
```

### 5. Hammerspoon Integration (FR-001, FR-002)

```bash
# Verify Hammerspoon config loaded
# Press Ctrl+Opt+T — native text dialog should appear
# Type "Integration test memory" and click Save
# Verify dark overlay notification appears and auto-dismisses

# Check file was created
ls -lt ~/.SYSTEM_NAME/files/memories/ | head -3
```

### 5b. Debug Log Viewer

```bash
# Press Ctrl+Opt+L — capture.log opens in default text editor
# Verify log entries show module load, capture events, and script execution
```

### 6. Re-index Verification (FR-013, SC-005)

```bash
# After any capture, check Khoj indexed it
sleep 30  # wait for re-index
curl -s "http://localhost:9371/api/search?q=test+memory&t=markdown" | head -20
```

Expected: Captured memory appears in search results.

## Running BDD Tests

```bash
# Install bats if not present
brew install bats-core

# Run all capture tests
bats tests/capture/

# Run specific test file
bats tests/capture/text-capture.bats
bats tests/capture/screen-capture.bats
bats tests/capture/audio-capture.bats
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Hotkey doesn't work | Accessibility permission not granted | System Settings → Privacy → Accessibility → enable Hammerspoon |
| Screenshot overlay appears but capture fails | Screen Recording permission not granted to Hammerspoon | System Settings → Privacy → Screen & System Audio Recording → enable Hammerspoon. May need to toggle off/on and restart Hammerspoon. |
| Screenshot: "snapshot returned nil" in log | Screen Recording permission granted but not effective | Toggle Hammerspoon OFF then ON in Screen Recording settings, then reload Hammerspoon config |
| Audio fails to record | Microphone permission missing | System Settings → Privacy → Microphone → enable Hammerspoon |
| Transcription empty | Whisper model not downloaded | Run: `curl -L -o ~/.SYSTEM_NAME/.sys/ggml-base.en.bin <model_url>` |
| No notification visible | Using `hs.alert` (dark overlay) — no Notification Center permission needed | Check Hammerspoon console for errors. `hs.alert` works without notification permissions. |
| `screencapture` from terminal fails | macOS 26+ does not inherit Screen Recording to child processes | This is expected — the system uses native `hs.screen:snapshot()` instead of `screencapture` |
| Debug log not opening | Log file doesn't exist yet | Trigger any capture action first, or check `~/.SYSTEM_NAME/.sys/capture.log` manually |
