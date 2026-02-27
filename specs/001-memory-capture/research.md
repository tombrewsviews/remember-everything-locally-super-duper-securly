# Research: Memory Capture System

**Feature**: 001-memory-capture
**Date**: 2026-02-27

## Technology Decisions

### Global Hotkey & UI Framework: Hammerspoon

**Decision**: Use Hammerspoon (Lua-based macOS automation) for global hotkeys and UI.

**Rationale**:
- Installable via `brew install --cask hammerspoon` — fits Script-Native Architecture principle
- No compiled binaries, no Xcode, no code signing required
- Provides `hs.hotkey.bind` for global shortcuts, `hs.dialog.textPrompt` for native text input, `hs.task.new` for async shell execution
- `hs.screen:snapshot(rect)` for native screen capture — uses Hammerspoon's own Screen Recording permission directly (avoids macOS 15+/26 permission inheritance issues with external tools like `screencapture`)
- `hs.canvas` for interactive region selection overlay (screenshot) and recording indicator (audio)
- `hs.dockicon.hide()` + `defaults write` for stealth — no dock icon
- `hs.alert.show` for transient dark overlay notifications (works without Notification Center permissions)
- `hs.menubar` for temporary recording indicator
- Mature project (10+ years), well-documented API, active community
- Configuration is a plain Lua file in `~/.hammerspoon/` — auditable text

**Alternatives Considered**:
- **Raycast extensions**: Requires Raycast app (third-party dependency beyond Homebrew), not shell-native
- **SwiftUI app**: Requires Xcode + code signing — violates Constitution Principle III
- **Electron/Tauri**: Heavy runtime, compiled binary — violates Principle III
- **Python + rumps**: Possible but limited UI (no native Spotlight-style bar), weaker hotkey support
- **Karabiner-Elements**: Hotkey-only, no UI components
- **macOS Shortcuts**: No global hotkey trigger without user interaction, limited scripting

### Audio Recording: sox

**Decision**: Use sox (Sound eXchange) CLI for microphone recording.

**Rationale**:
- Installable via `brew install sox` — fits Script-Native principle
- Simple CLI: `sox -d -r 16000 -c 1 -b 16 output.wav` records from default mic
- Lightweight (~5MB), no GUI, no daemon
- Can be started/stopped from shell scripts via PID management
- Supports WAV output natively (required by whisper-cpp)
- 16kHz mono 16-bit PCM is optimal for speech recognition

**Alternatives Considered**:
- **ffmpeg**: More complex CLI, heavier install, designed for video — overkill for audio-only
- **rec (sox alias)**: Same as sox, just a symlink
- **macOS `say`/AudioToolbox**: No CLI recording API without Swift/ObjC
- **Audacity CLI**: No headless mode

### Local Transcription: whisper-cpp

**Decision**: Use whisper-cpp CLI with ggml-base.en model for local speech-to-text.

**Rationale**:
- Installable via `brew install whisper-cpp` — fits Script-Native principle
- CLI invocation: `whisper-cpp -m model.bin -f audio.wav` — scriptable
- ggml-base.en model (~140MB) balances quality vs. size for English
- Fully local — zero network requests, satisfies Privacy-First principle
- Processes 2-minute audio in ~3-5 seconds on Apple Silicon — meets SC-003

**Alternatives Considered**:
- **OpenAI Whisper (Python)**: Requires Python environment + torch (~2GB) — too heavy
- **Vosk**: Good accuracy but more complex setup, less Homebrew-native
- **macOS Speech Recognition**: Requires Objective-C/Swift bridge — violates Principle III
- **Cloud APIs (Google/AWS)**: Violate Privacy-First principle

### Testing: bats-core

**Decision**: Use bats-core (Bash Automated Testing System) for shell script tests.

**Rationale**:
- Installable via `brew install bats-core` — fits Script-Native principle
- Native bash test framework — tests shell scripts in their own language
- Supports setup/teardown, assertions, TAP output format
- Tests can create temp directories, mock commands, validate file output
- Pairs with BDD feature files (Gherkin → bats step definitions)

**Alternatives Considered**:
- **shunit2**: Less active development, fewer features
- **pytest + subprocess**: Adds Python dependency for testing bash scripts — unnecessary
- **shellspec**: Good but less widely adopted than bats

### Whisper Model: ggml-base.en.bin

**Decision**: Use the English-only base model (140MB).

**Rationale**:
- Best accuracy-to-size ratio for English-only use case
- ~140MB download from HuggingFace (one-time during install)
- Fast inference on Apple Silicon (< 3s for 2 min audio)
- English-only model is more accurate than multilingual for English content

**Alternatives Considered**:
- **ggml-tiny.en** (~75MB): Faster but noticeably lower accuracy
- **ggml-small.en** (~460MB): Better accuracy but slower, larger download
- **ggml-medium.en** (~1.5GB): Overkill for quick voice notes

## Tessl Tiles

### Installed Tiles

No new tiles installed for this feature. Technologies used (Hammerspoon/Lua, bash, sox, whisper-cpp, bats) do not have Tessl documentation tiles available in the registry.

### Technologies Without Tiles

- Hammerspoon (Lua): No tile found (hammerjs is unrelated — JavaScript touch gestures)
- bash/shell scripting: No tile found
- sox: No tile found
- whisper-cpp: No tile found
- bats-core: No tile found

### Pre-existing Tiles In Use

- `tessleng/core-security-rules` — input validation and injection prevention rules applied to shell script design
- `tessleng/owasp-security-rules` — OS command injection defense patterns applied to capture scripts

## Security Considerations

### Shell Script Input Validation (per Constitution Security Standards)

All capture scripts receive user input (text content, file paths). Per the constitution and OWASP rules:
- Text input passed as arguments must use proper quoting (`"$1"`) to prevent word splitting
- File paths must be validated (no path traversal, no command injection)
- Temporary file names use dot-prefix and UUIDs (not user-controllable)
- PID files in `/tmp/` use dot-prefix with system name to avoid collisions

### macOS Permission Model

Hammerspoon requires three explicit macOS permissions (user must grant manually):
1. **Accessibility** (System Settings → Privacy → Accessibility): Required for global hotkeys
2. **Screen & System Audio Recording** (System Settings → Privacy → Screen & System Audio Recording): Required for `hs.screen:snapshot()` — Hammerspoon captures natively using its own permission (does NOT delegate to `/usr/sbin/screencapture` which has permission inheritance issues on macOS 15+/26)
3. **Microphone** (System Settings → Privacy → Microphone): Required for sox audio recording

These cannot be granted programmatically — the installer prints clear instructions.

**macOS 26 (Tahoe) Note**: The external `screencapture` tool launched via `hs.task` does not inherit Hammerspoon's Screen Recording permission on macOS 26. It exits with code 0 but produces 0-byte files. This was the primary motivation for switching to Hammerspoon's native `hs.screen:snapshot(rect)` API, which uses the permission directly.

## File Format Decision

### Memory Markdown with YAML Front-matter

```markdown
---
type: text|screenshot|audio
captured: 2026-02-27T14:30:22-08:00
source: capture
---

# Memory — 2026-02-27 14:30

[content here]
```

**Rationale**:
- Khoj indexes markdown files and uses H1 headers for chunk boundaries
- YAML front-matter provides machine-readable metadata without breaking Khoj's parser
- ISO 8601 timestamps with timezone for unambiguous chronology
- H1 with date enables temporal search in Khoj
- Relative image paths (`assets/scr_*.png`) work with Khoj's file-based content source

### Naming Convention

| Type | Filename | Example |
|------|----------|---------|
| Text | `mem_YYYYMMDD_HHMMSS_text.md` | `mem_20260227_143022_text.md` |
| Screenshot | `mem_YYYYMMDD_HHMMSS_screenshot.md` | `mem_20260227_143023_screenshot.md` |
| Audio | `mem_YYYYMMDD_HHMMSS_audio.md` | `mem_20260227_150100_audio.md` |
| Screenshot image | `assets/scr_YYYYMMDD_HHMMSS.png` | `assets/scr_20260227_143023.png` |
| Audio recording | `assets/audio_YYYYMMDD_HHMMSS.wav` | `assets/audio_20260227_150100.wav` |

Timestamp-based naming prevents collisions and enables chronological sorting.
