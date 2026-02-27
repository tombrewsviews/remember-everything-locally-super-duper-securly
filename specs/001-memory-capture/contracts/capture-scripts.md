# Capture Script Contracts

**Feature**: 001-memory-capture
**Date**: 2026-02-27

## Script Interface Contracts

All capture scripts follow the same conventions as existing project scripts:
- Shebang: `#!/usr/bin/env bash`
- Use `set -e` for fail-fast behavior
- `SYSTEM_NAME` placeholder replaced by `install.sh` via sed
- Exit code 0 on success, non-zero on failure
- Stdout: machine-readable output for Hammerspoon (paths, durations)
- Stderr: human-readable errors (logged by Hammerspoon)

---

### capture-text.sh

**Purpose**: Save text input as a timestamped markdown memory file.

**Interface**:
```
capture-text.sh <text_content>
```

**Arguments**:
| Arg | Required | Description |
|-----|----------|-------------|
| $1 | Yes | Text content to save (may contain spaces, special chars) |

**Output** (stdout):
```
<absolute_path_to_created_memory_file>
```

**Behavior**:
1. Validate input is non-empty
2. Generate timestamp: `YYYYMMDD_HHMMSS`
3. Create `mem_{timestamp}_text.md` with YAML front-matter and content
4. Write to `~/.{SYSTEM_NAME}/files/memories/`
5. Trigger async re-index via curl to Khoj
6. Print created file path to stdout

**Error Handling**:
- Empty input: exit 1, stderr "Error: empty text"
- Write failure: exit 1, stderr "Error: cannot write to memories directory"
- Re-index failure: log warning, do NOT exit with error (re-index is best-effort)

---

### capture-screen.sh

**Purpose**: Save a screenshot image and create a referencing markdown memory file.

**Interface**:
```
capture-screen.sh <temp_image_path> [annotation_text]
```

**Arguments**:
| Arg | Required | Description |
|-----|----------|-------------|
| $1 | Yes | Absolute path to temporary screenshot PNG |
| $2 | No | Optional text annotation |

**Output** (stdout):
```
<absolute_path_to_created_memory_file>
```

**Behavior**:
1. Validate temp image exists and is non-zero size
2. Generate timestamp: `YYYYMMDD_HHMMSS`
3. Move image to `~/.{SYSTEM_NAME}/files/memories/assets/scr_{timestamp}.png`
4. Create `mem_{timestamp}_screenshot.md` with front-matter, annotation, and image reference
5. Remove temp file (if move succeeded)
6. Trigger async re-index
7. Print created file path to stdout

**Error Handling**:
- Missing image: exit 1, stderr "Error: image not found"
- Zero-size image: exit 1, stderr "Error: image is empty"
- Move failure: exit 1, stderr "Error: cannot move image to assets"
- Re-index failure: log warning, continue

---

### capture-audio.sh

**Purpose**: Start/stop audio recording and transcribe.

**Interface**:
```
capture-audio.sh start
capture-audio.sh stop
```

**Arguments**:
| Arg | Required | Description |
|-----|----------|-------------|
| $1 | Yes | Action: "start" or "stop" |

**Output** (stdout):

For `start`:
```
recording
```

For `stop`:
```
<duration_seconds>
<absolute_path_to_created_memory_file>
```

**Behavior — start**:
1. Check no recording already active (PID file exists and process running)
2. Generate temp WAV path: `/tmp/.memrec_{SYSTEM_NAME}.wav`
3. Start `sox -d -r 16000 -c 1 -b 16 /tmp/.memrec_{SYSTEM_NAME}.wav` in background
4. Write PID to `/tmp/.memrec_{SYSTEM_NAME}.pid`
5. Print "recording" to stdout

**Behavior — stop**:
1. Read PID from `/tmp/.memrec_{SYSTEM_NAME}.pid`
2. Send SIGTERM to sox process, wait for it to finish writing
3. Calculate recording duration from WAV file header
4. Generate timestamp: `YYYYMMDD_HHMMSS`
5. Run whisper-cpp transcription on the WAV file
6. Move WAV to `~/.{SYSTEM_NAME}/files/memories/assets/audio_{timestamp}.wav`
7. Create `mem_{timestamp}_audio.md` with front-matter, transcription, and audio reference
8. If transcription failed: use fallback text "[Transcription unavailable — audio preserved]"
9. Clean up PID file and temp files
10. Trigger async re-index
11. Print duration (seconds) and file path to stdout (two lines)

**Error Handling**:
- `start` when already recording: exit 1, stderr "Error: recording already active"
- `start` when sox unavailable: exit 1, stderr "Error: sox not found"
- `stop` when not recording: exit 1, stderr "Error: no active recording"
- Transcription failure: continue with fallback text, do NOT exit with error
- WAV move failure: exit 1, stderr "Error: cannot save audio file"
- Re-index failure: log warning, continue

---

## Hammerspoon Lua Module Contract

### memcapture.lua

**Purpose**: Global hotkey bindings, native screen capture, canvas-based UI overlays, dialog prompts, and shell script orchestration.

**Location**: `~/.hammerspoon/memcapture.lua` (loaded by init.lua)

**Hotkey Bindings**:
| Shortcut | Action |
|----------|--------|
| Ctrl+Opt+T | Show text capture dialog (`hs.dialog.textPrompt`) |
| Ctrl+Opt+S | Start native screenshot region selection (`hs.canvas` overlay + `hs.screen:snapshot`) |
| Ctrl+Opt+A | Toggle audio recording (start/stop) |
| Ctrl+Opt+L | Open capture debug log in default editor |

**Dependencies**:
- `hs.hotkey` — Global keyboard shortcuts
- `hs.task` — Async shell script execution
- `hs.screen` — Native screen capture via `hs.screen:snapshot(rect)`
- `hs.canvas` — Interactive region selection overlay (screenshot) + recording indicator (audio)
- `hs.dialog` — Native macOS text prompt dialogs (text capture + screenshot annotation)
- `hs.alert` — Dark overlay notifications (replaces `hs.notify` — works without Notification permission)
- `hs.menubar` — Recording indicator (audio only, alongside canvas overlay)
- `hs.timer` — Delayed execution (`doAfter` for overlay dismiss → capture timing)
- `hs.styledtext` — Styled overlay text (selection instructions)
- `hs.dockicon` — Hide dock icon
- `hs.urlevent` — Open debug log file in editor

**State Management**:
- `isRecording` (boolean): tracks audio recording state
- `recordingIndicator` (hs.menubar or nil): menu bar red dot during recording
- `recordingCanvas` (hs.canvas or nil): on-screen recording overlay during audio capture
- `selectionCanvas` (hs.canvas or nil): full-screen overlay during screenshot region selection
- `selectionOverlay` (hs.canvas or nil): blue selection rectangle during screenshot drag
- `escHotkey` (hs.hotkey or nil): temporary Escape key binding during screenshot selection

**Shell Script Paths**:
All scripts located at `~/.{SYSTEM_NAME}/.sys/`:
- `capture-text.sh`
- `capture-screen.sh`
- `capture-audio.sh`

**Logging**:
All actions logged to `~/.{SYSTEM_NAME}/.sys/capture.log` with timestamps. Log function writes timestamped entries for debugging (module load, hotkey invocations, script execution, errors).

**Notification Pattern**:
All notifications use `hs.alert.show` with:
- Duration: 2 seconds (auto-dismiss dark overlay)
- Messages: "Memory saved" / "Screenshot saved" / "Voice note saved (Xs)" / error messages
- No sound, no Notification Center permission required (stealth)
- Error messages include hint text (e.g., "Check Screen Recording permission for Hammerspoon")
