# Implementation Plan: Memory Capture System

**Branch**: `001-memory-capture` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-memory-capture/spec.md`

## Summary

Multimodal memory capture for macOS via global keyboard shortcuts (text, screenshot, audio). Hammerspoon provides hotkeys, native UI dialogs, and interactive canvas overlays. Three shell scripts handle capture logic: text → markdown, screenshot → PNG + markdown, audio → WAV + whisper-cpp transcription + markdown. All files land in `~/.{system_name}/files/memories/` for Khoj indexing. Installed via the existing `install.sh`.

## Technical Context

**Language/Version**: Bash 5.x (capture scripts), Lua 5.4 (Hammerspoon config)
**Primary Dependencies**: Hammerspoon (hotkeys + canvas UI + native screenshots), sox (audio recording), whisper-cpp (local transcription), bats-core (testing)
**Storage**: Filesystem — markdown files with YAML front-matter in `~/.{system_name}/files/memories/`, binary assets in `memories/assets/`
**Testing**: bats-core (shell script unit/integration tests), shellcheck (linting)
**Target Platform**: macOS 13+ (Ventura and later, Apple Silicon + Intel). Tested on macOS 26 (Tahoe).
**Project Type**: Single project — shell scripts + Lua config extending existing install
**Performance Goals**: Text/screenshot < 1s end-to-end, audio transcription < 5s for 2 min recording
**Constraints**: Zero network requests for capture/transcription, < 200MB additional disk (mostly whisper model), max 2 user decisions per capture
**Scale/Scope**: Single user, local filesystem, ~100s of memories per day max

## Constitution Check

*GATE: Must pass before research. Re-checked after design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Privacy-First | PASS | All processing local. whisper-cpp runs offline. No data transmitted. |
| II. Stealth by Default | PASS | `hs.dockicon.hide()`, `.metadata_never_index`, dot-prefix temps, transient-only indicators. |
| III. Script-Native Architecture | PASS | All components are bash scripts + Lua config + Homebrew packages. No compiled binaries, no Xcode, no code signing. |
| IV. Test-Driven Development | PASS | bats-core tests written before capture scripts. BDD .feature files generated via IIKit before implementation. |
| V. Capture Simplicity | PASS | Text: 1 decision (type + Enter). Screenshot: 1-2 decisions (select + optional note). Audio: 1 decision (toggle). All < 5s. |
| Security: Input validation | PASS | All scripts use proper quoting, validate inputs, no command injection vectors. |
| Security: No plaintext secrets | PASS | No secrets involved in capture flow. |
| Workflow: shellcheck | PASS | All bash scripts will pass shellcheck before commit. |

**CONSTITUTION GATE: ALL CLEAR — 0 violations**

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    macOS Desktop                     │
│                                                      │
│  ┌──────────────────┐   Ctrl+Opt+T/S/A/L            │
│  │   Hammerspoon    │◄──── Global Hotkeys            │
│  │  (memcapture.lua)│                                │
│  └──┬───┬───┬───────┘                                │
│     │   │   │                                        │
│     │   │   │  hs.task.new (async)                   │
│     │   │   │                                        │
│     │   │   │  hs.screen:snapshot (native capture)   │
│     │   │   │  hs.canvas (region select overlay)     │
│     │   │   │  hs.dialog (text prompts)              │
│     │   │   │                                        │
│     ▼   ▼   ▼                                        │
│  ┌────┐┌────┐┌────┐                                  │
│  │text││scrn││audi│  Shell Scripts                    │
│  │.sh ││.sh ││o.sh│  (~/.sys/)                       │
│  └──┬─┘└─┬──┘└─┬──┘                                  │
│     │    │     │                                      │
│     │    │     ├──► sox (record mic)                  │
│     │    │     └──► whisper-cpp (transcribe)          │
│     │    │                                            │
│     ▼                                                 │
│  ┌──────────────────────────────────┐                │
│  │  ~/.{name}/files/memories/       │                │
│  │    mem_*_text.md                 │                │
│  │    mem_*_screenshot.md           │                │
│  │    mem_*_audio.md                │                │
│  │    assets/                       │                │
│  │      scr_*.png                   │                │
│  │      audio_*.wav                 │                │
│  └──────────────┬───────────────────┘                │
│                 │ curl POST /api/update               │
│                 ▼                                     │
│  ┌──────────────────────────────────┐                │
│  │  Khoj (localhost:9371)           │                │
│  │  Indexes markdown + images       │                │
│  └──────────────────────────────────┘                │
└─────────────────────────────────────────────────────┘
```

## Project Structure

### Documentation (this feature)

```text
specs/001-memory-capture/
  spec.md              # Feature specification
  plan.md              # This file
  research.md          # Technology decisions and rationale
  data-model.md        # Entity definitions and file formats
  quickstart.md        # Test scenarios and troubleshooting
  contracts/           # Script interface contracts
    capture-scripts.md # CLI contracts for all capture scripts
  checklists/
    requirements.md    # Spec quality checklist
  tasks.md             # Implementation tasks (created by /iikit-05-tasks)
```

### Source Code (repository root)

```text
scripts/
  capture-text.sh        # Text capture backend (template — sed-stamped)
  capture-screen.sh      # Screenshot capture backend (template)
  capture-audio.sh       # Audio capture backend (template)

templates/
  memcapture.lua         # Hammerspoon module (template — sed-stamped)

tests/
  capture/
    text-capture.bats    # bats tests for capture-text.sh
    screen-capture.bats  # bats tests for capture-screen.sh
    audio-capture.bats   # bats tests for capture-audio.sh
    helpers/
      setup.bash         # Shared test helpers (temp dir, mocks)

install.sh               # Modified — new section for capture dependencies
```

**Structure Decision**: Follows the existing project pattern — scripts in `scripts/`, templates in `templates/`, tests in new `tests/` directory. No new top-level directories beyond `tests/`. All scripts are sed-templated with `SYSTEM_NAME` placeholder, matching the existing `watcher.sh`, `reindex.sh`, `setgrove.sh` pattern.

## Dependencies

| Package | Install Method | Size | Purpose | Constitution Check |
|---------|---------------|------|---------|-------------------|
| Hammerspoon | `brew install --cask hammerspoon` | ~30MB | Global hotkeys, native screen capture (`hs.screen:snapshot`), canvas UI overlays, dialog prompts, async task runner | III: Homebrew-installable ✓ |
| sox | `brew install sox` | ~5MB | CLI audio recording from microphone | III: Homebrew-installable ✓ |
| whisper-cpp | `brew install whisper-cpp` | ~2MB | Local speech-to-text CLI | III: Homebrew-installable, I: fully local ✓ |
| ggml-base.en.bin | curl from HuggingFace | ~140MB | Whisper model weights (one-time download) | I: stored locally, no runtime network ✓ |
| bats-core | `brew install bats-core` | ~1MB | Shell script test framework | IV: TDD support ✓ |
| shellcheck | `brew install shellcheck` | ~5MB | Shell script linter | Workflow: shellcheck linting ✓ |

**Total additional disk**: ~183MB (mostly the whisper model)

## Capture Flow Details

### Quick Text (Ctrl+Opt+T)

1. User presses `Ctrl+Opt+T`
2. Hammerspoon shows `hs.dialog.textPrompt` (native macOS text input dialog)
3. User types or pastes text, clicks Save (or Cancel to dismiss)
4. Dialog dismisses instantly
5. `hs.task.new` calls `capture-text.sh` asynchronously with the text as argument
6. Script writes markdown file, triggers async Khoj re-index
7. `hs.alert.show` displays "Memory saved" (dark overlay, auto-dismiss 2s)
8. **Target latency: < 200ms from Save to file written**

### Screenshot (Ctrl+Opt+S)

1. User presses `Ctrl+Opt+S`
2. Hammerspoon shows full-screen `hs.canvas` overlay (semi-transparent dark, instruction text centered)
3. User clicks and drags to select region — live blue selection rectangle shown via second `hs.canvas`
4. On mouse-up: overlay and selection canvases are dismissed, `hs.screen:snapshot(rect)` captures the region natively
5. If capture succeeded: `hs.dialog.textPrompt` shows for optional annotation
6. User types note + clicks Save, or clicks Skip for no annotation
7. `hs.task.new` calls `capture-screen.sh` with temp PNG path and annotation
8. Script moves PNG to assets/, writes markdown (with OCR text via describe-image), triggers re-index
9. `hs.alert.show` displays "Screenshot saved" (dark overlay, auto-dismiss 2s)
10. **Target latency: < 1s from annotation confirm to file written**

**Region Selection Details**:
- Overlay canvas covers entire main screen at `hs.canvas.windowLevels.overlay`
- Selection rectangle rendered as blue stroke+fill on a second canvas at `overlay + 1`
- Minimum selection size: 10×10 pixels (smaller treated as cancelled)
- Escape key cancels via `hs.hotkey.bind`; all canvases cleaned up
- 0.2s delay between overlay dismiss and `hs.screen:snapshot()` to avoid capturing the overlay itself
- Uses Hammerspoon's own Screen Recording permission directly (no external `screencapture` tool)

### Audio Toggle (Ctrl+Opt+A)

1. **First press**: Hammerspoon calls `capture-audio.sh start`
   - sox begins recording in background (via nohup, SIGINT for graceful stop)
   - Red "Recording" `hs.canvas` overlay appears in top-right corner
   - `hs.menubar` indicator also shown
   - `hs.alert.show` displays "Recording — press Ctrl+Opt+A to stop"
2. **Second press**: Hammerspoon calls `capture-audio.sh stop`
   - sox stops, whisper-cpp transcribes
   - Script outputs duration and file path
   - Recording overlay and menu bar indicator removed
   - `hs.alert.show` displays "Voice note saved (Xs)" (auto-dismiss 2s)
3. **Target latency: < 5s from stop to file written** (for recordings under 2 min)

### Debug Log Viewer (Ctrl+Opt+L)

1. User presses `Ctrl+Opt+L`
2. Hammerspoon opens the capture log file in the default text editor via `hs.urlevent.openURL`
3. Log file located at `~/.{system_name}/.sys/capture.log`

## Installer Integration

New section in `install.sh` after step 13 (LaunchAgent), before step 14 (access code):

### Step 13b: Memory Capture Dependencies

```bash
# Install capture tools
brew install --cask hammerspoon 2>/dev/null || true
brew install sox 2>/dev/null || true
brew install whisper-cpp 2>/dev/null || true
brew install bats-core 2>/dev/null || true
brew install shellcheck 2>/dev/null || true
```

### Step 13c: Whisper Model Download

```bash
WHISPER_MODEL="$SYS_DIR/.sys/ggml-base.en.bin"
if [[ ! -f "$WHISPER_MODEL" ]]; then
  echo "Downloading whisper model (~140MB)..."
  curl -L -o "$WHISPER_MODEL" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
fi
```

### Step 13d: Capture Directory Structure

```bash
mkdir -p "$SYS_DIR/files/memories/assets"
touch "$SYS_DIR/files/memories/.metadata_never_index"
```

### Step 13e: Install Capture Scripts

```bash
for script in capture-text.sh capture-screen.sh capture-audio.sh; do
  sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/scripts/$script" > "$SYS_DIR/.sys/$script"
  chmod +x "$SYS_DIR/.sys/$script"
done
```

### Step 13f: Deploy Hammerspoon Config

```bash
# Hide dock icon
defaults write org.hammerspoon.Hammerspoon MJShowDockIconKey -bool false

# Deploy Lua module
mkdir -p "$HOME/.hammerspoon"
sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/templates/memcapture.lua" > "$HOME/.hammerspoon/memcapture.lua"

# Add to init.lua if not already present
INIT_LUA="$HOME/.hammerspoon/init.lua"
touch "$INIT_LUA"
if ! grep -q "memcapture" "$INIT_LUA"; then
  echo 'require("memcapture")' >> "$INIT_LUA"
fi

# Reload Hammerspoon config
hs -c "hs.reload()" 2>/dev/null || true
```

### Step 13g: Permission Reminder

```bash
echo ""
echo "  Memory Capture requires macOS permissions:"
echo "    1. System Settings → Privacy → Accessibility → Hammerspoon"
echo "    2. System Settings → Privacy → Screen Recording → Hammerspoon"
echo "    3. System Settings → Privacy → Microphone → Hammerspoon"
echo ""
```

## Stealth Measures

| Measure | Implementation | Constitutional Principle |
|---------|---------------|------------------------|
| No dock icon | `hs.dockicon.hide()` + `defaults write MJShowDockIconKey false` | II |
| No persistent menu bar | Menu bar item only during audio recording, removed on stop | II |
| Spotlight exclusion | `.metadata_never_index` in `memories/` directory | II |
| Temp file stealth | Dot-prefixed temp files in `/tmp/` (e.g., `/tmp/.memcap_*`) | II |
| Silent failures | Capture errors show brief `hs.alert` overlay only, auto-dismiss | II |
| No login items | Hammerspoon auto-starts via its own preference, not a new LaunchAgent | II |
| Process name | Hammerspoon runs as "Hammerspoon" (standard process name, not custom) | II |

## Complexity Tracking

No constitution violations to justify. All technical decisions align with constitutional principles.
