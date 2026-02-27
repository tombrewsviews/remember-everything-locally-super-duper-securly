# Data Model: Memory Capture System

**Feature**: 001-memory-capture
**Date**: 2026-02-27

## Entities

### Memory

A single captured unit of information, persisted as a markdown file with YAML front-matter.

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | enum: text, screenshot, audio | Yes | Capture modality |
| captured | ISO 8601 datetime with timezone | Yes | When the memory was captured |
| source | string (always "capture") | Yes | Origin of the memory (distinguishes from imports) |
| annotation | string | No | User-provided text note (screenshots, audio) |
| asset_path | relative file path | No | Path to associated binary asset (screenshots, audio) |
| transcription | string | No | Auto-generated text from audio (audio type only) |
| duration | integer (seconds) | No | Recording length (audio type only) |

**Validation Rules**:
- `type` must be one of: text, screenshot, audio
- `captured` must be valid ISO 8601 with timezone offset
- `source` is always "capture" for this feature (other values used by watcher imports)
- `annotation` may contain any UTF-8 text; YAML-sensitive characters must be escaped in front-matter
- `asset_path` must be a relative path starting with `assets/`

**State Transitions**:
- Created → Indexed (after Khoj re-index completes)
- No delete/update states — memories are append-only

### Asset

A binary file associated with a memory (screenshot PNG or audio WAV).

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| filename | string | Yes | Timestamped filename (e.g., scr_20260227_143023.png) |
| format | enum: png, wav | Yes | File format |
| size_bytes | integer | Yes | File size for validation |
| created_at | ISO 8601 datetime | Yes | File creation timestamp |

**Validation Rules**:
- PNG files must have valid PNG magic bytes (89 50 4E 47)
- WAV files must have valid RIFF/WAVE header
- Files must be non-zero size
- Filenames must match the pattern: `(scr|audio)_YYYYMMDD_HHMMSS.(png|wav)`

### Capture Session (transient — not persisted)

A transient interaction from shortcut press to file creation.

**Attributes**:

| Field | Type | Description |
|-------|------|-------------|
| modality | enum: text, screenshot, audio | Which capture type |
| started_at | timestamp | When shortcut was pressed |
| status | enum: active, completed, cancelled, failed | Current state |
| temp_files | list of file paths | Temporary files to clean up |

**State Transitions**:
```
[idle] → shortcut pressed → [active]
[active] → user confirms → [completed] → Memory created
[active] → user cancels (Escape) → [cancelled] → cleanup temp files
[active] → error occurs → [failed] → notification + cleanup
```

## Directory Structure

```
~/.{system_name}/
  files/
    memories/
      .metadata_never_index          # Spotlight exclusion
      mem_20260227_143022_text.md
      mem_20260227_143023_screenshot.md
      mem_20260227_150100_audio.md
      assets/
        scr_20260227_143023.png
        audio_20260227_150100.wav
```

## Relationships

```
Memory (1) ──references──> (0..1) Asset
  - text memories have no asset
  - screenshot memories reference exactly one PNG asset
  - audio memories reference exactly one WAV asset

Capture Session (1) ──produces──> (0..1) Memory
  - successful session produces one memory
  - cancelled/failed session produces no memory
```

## File Format Examples

### Text Memory

```markdown
---
type: text
captured: 2026-02-27T14:30:22-08:00
source: capture
---

# Memory — 2026-02-27 14:30

Remember to buy groceries for dinner tonight.
```

### Screenshot Memory (with annotation)

```markdown
---
type: screenshot
captured: 2026-02-27T14:30:23-08:00
source: capture
annotation: Error dialog from build system
---

# Memory — 2026-02-27 14:30

Error dialog from build system

![screenshot](assets/scr_20260227_143023.png)
```

### Audio Memory

```markdown
---
type: audio
captured: 2026-02-27T15:01:00-08:00
source: capture
duration: 45
---

# Memory — 2026-02-27 15:01

I had an idea about the project architecture. We should consider
splitting the backend into two services — one for indexing and one
for search. This would let us scale them independently.

[Audio: assets/audio_20260227_150100.wav]
```

### Audio Memory (transcription failed)

```markdown
---
type: audio
captured: 2026-02-27T15:05:00-08:00
source: capture
duration: 30
---

# Memory — 2026-02-27 15:05

[Transcription unavailable — audio preserved]

[Audio: assets/audio_20260227_150500.wav]
```
