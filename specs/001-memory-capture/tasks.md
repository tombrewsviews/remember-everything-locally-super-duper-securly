# Tasks: Memory Capture System

**Input**: Design documents from `/specs/001-memory-capture/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/capture-scripts.md
**Branch**: `001-memory-capture`

**Tests**: TDD is MANDATORY per CONSTITUTION.md Principle IV. All bats tests are written FIRST, verified to FAIL, then production code is implemented until tests pass.

**Organization**: Tasks grouped by user story. Shared infrastructure in Setup/Foundational. Each story independently implementable and testable after foundational phase completes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions
- **Traceability**: Test spec IDs in explicit comma-separated lists

---

## Phase 1: Setup

**Purpose**: Create directory structure and test infrastructure

- [x] T001 Create test directory structure: `tests/capture/helpers/` at repo root
- [x] T002 [P] Create shared test helper in `tests/capture/helpers/setup.bash` — temp directory creation, mock command helpers, fixture generators, common assertions for file naming/front-matter validation
- [x] T003 [P] Configure shellcheck integration — add `.shellcheckrc` at repo root with project-wide settings

**Checkpoint**: Test infrastructure ready — bats tests can now be written

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure shared by ALL capture modalities — memories directory, file naming, front-matter generation, reindex trigger

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Create `scripts/capture-text.sh` skeleton — shebang, `set -e`, SYSTEM_NAME placeholder, directory variables, empty main function, input validation stub [TS-007]
- [x] T005 [P] Create `scripts/capture-screen.sh` skeleton — same conventions, image validation stub [TS-017, TS-018]
- [x] T006 [P] Create `scripts/capture-audio.sh` skeleton — same conventions, start/stop subcommands, PID management stubs [TS-029, TS-030]
- [x] T007 Create shared shell functions file `scripts/capture-common.sh` — timestamp generation (`YYYYMMDD_HHMMSS`), YAML front-matter writer, memories directory path resolver, async reindex trigger (curl POST to Khoj), temp file cleanup utility

**Checkpoint**: Foundational scripts exist with shared infrastructure — story-specific implementation can begin

---

## Phase 3: User Story 1 — Quick Text Capture (Priority: P1) MVP

**Goal**: Press Ctrl+Opt+T → type text → Enter → timestamped markdown saved
**Independent Test**: Press shortcut, type sentence, Enter, verify `mem_*_text.md` exists with correct front-matter and content

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T008 [P] [US1] Write bats contract tests in `tests/capture/text-capture.bats` — test correct file naming pattern, YAML front-matter fields (type, captured, source), body content preservation, exit code 0 on success [TS-006, TS-008]
- [x] T009 [P] [US1] Write bats error-handling tests in `tests/capture/text-capture.bats` — test empty input rejection (exit 1, stderr message), special character escaping in front-matter [TS-007, TS-008]

### Implementation for User Story 1

- [x] T010 [US1] Implement `scripts/capture-text.sh` — receive text as $1, validate non-empty, generate timestamp, write markdown with YAML front-matter and body, trigger async reindex, output file path to stdout [TS-002, TS-006, TS-007, TS-008]
- [x] T011 [US1] Run shellcheck on `scripts/capture-text.sh` and fix all warnings
- [x] T012 [US1] Verify bats tests pass for text capture — all T008, T009 tests green

**Checkpoint**: `capture-text.sh` fully functional and tested — text capture pipeline works end-to-end from CLI

---

## Phase 4: User Story 2 — Screenshot Capture with Annotation (Priority: P1)

**Goal**: Press Ctrl+Opt+S → select region → optional annotation → screenshot + markdown saved
**Independent Test**: Call `capture-screen.sh` with a test PNG and annotation, verify markdown + moved PNG in assets/

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T013 [P] [US2] Write bats contract tests in `tests/capture/screen-capture.bats` — test correct file naming (md + png), PNG moved to assets/, markdown references image with relative path, annotation included in front-matter and body [TS-016, TS-019]
- [x] T014 [P] [US2] Write bats error-handling tests in `tests/capture/screen-capture.bats` — test missing image rejection (exit 1), zero-size image rejection (exit 1), temp file cleanup after success [TS-017, TS-018]

### Implementation for User Story 2

- [x] T015 [US2] Implement `scripts/capture-screen.sh` — receive temp image path + optional annotation, validate image exists and non-zero, generate timestamp, move PNG to assets/, write markdown with front-matter and image reference, trigger async reindex, output file path [TS-011, TS-013, TS-014, TS-016, TS-017, TS-018, TS-019]
- [x] T016 [US2] Run shellcheck on `scripts/capture-screen.sh` and fix all warnings
- [x] T017 [US2] Verify bats tests pass for screenshot capture — all T013, T014 tests green

**Checkpoint**: `capture-screen.sh` fully functional — screenshot capture pipeline works end-to-end from CLI

---

## Phase 5: User Story 3 — Audio Recording with Local Transcription (Priority: P2)

**Goal**: Press Ctrl+Opt+A → start recording → press again → stop + transcribe → markdown + audio saved
**Independent Test**: Call `capture-audio.sh start` then `stop`, verify WAV in assets/, markdown with transcription text

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T018 [P] [US3] Write bats contract tests in `tests/capture/audio-capture.bats` — test start action (PID file created, stdout "recording", exit 0), stop action (markdown + WAV created, PID cleaned, duration + path output) [TS-027, TS-028]
- [x] T019 [P] [US3] Write bats error-handling tests in `tests/capture/audio-capture.bats` — test start-when-already-recording rejection, stop-when-not-recording rejection, transcription failure fallback text [TS-029, TS-030, TS-031]

### Implementation for User Story 3

- [x] T020 [US3] Implement `scripts/capture-audio.sh` start action — check no active recording, start sox in background, write PID file, output "recording" [TS-020, TS-027, TS-029]
- [x] T021 [US3] Implement `scripts/capture-audio.sh` stop action — read PID, kill sox, calculate duration from WAV, run whisper-cpp transcription, move WAV to assets/, write markdown with transcription + audio reference, cleanup PID/temp, trigger reindex [TS-021, TS-022, TS-028, TS-030]
- [x] T022 [US3] Implement transcription failure fallback — if whisper-cpp fails or produces empty output, use "[Transcription unavailable — audio preserved]" as body text [TS-031]
- [x] T023 [US3] Run shellcheck on `scripts/capture-audio.sh` and fix all warnings
- [x] T024 [US3] Verify bats tests pass for audio capture — all T018, T019 tests green

**Checkpoint**: `capture-audio.sh` fully functional — audio capture + transcription pipeline works end-to-end from CLI

---

## Phase 6: User Story 4 — Stealth Operation (Priority: P1)

**Goal**: No dock icon, no menu bar (except during recording), Spotlight exclusion, auto-dismiss notifications, stealth temp files
**Independent Test**: Launch system, verify no dock icon, no menu bar item when idle, `.metadata_never_index` exists

### Implementation for User Story 4

- [x] T025 [US4] Create `templates/memcapture.lua` — Hammerspoon module with `hs.dockicon.hide()`, module-level state variables (isRecording, recordingIndicator, textChooser), SYSTEM_NAME placeholder for script paths [TS-032, TS-033]
- [x] T026 [US4] Implement text capture hotkey binding in `templates/memcapture.lua` — Ctrl+Opt+T binds to `hs.chooser` show, chooser callback calls `capture-text.sh` via `hs.task.new`, `hs.notify` with 2s auto-dismiss on success, duplicate shortcut focuses existing bar [TS-001, TS-002, TS-003, TS-004, TS-009]
- [x] T027 [US4] Implement screenshot capture hotkey binding in `templates/memcapture.lua` — Ctrl+Opt+S invokes `/usr/sbin/screencapture -i -s` via `hs.task.new`, on success shows chooser for annotation, calls `capture-screen.sh`, notification on complete [TS-010, TS-012, TS-013, TS-014, TS-015]
- [x] T028 [US4] Implement audio toggle hotkey binding in `templates/memcapture.lua` — Ctrl+Opt+A toggles isRecording state, first press calls `capture-audio.sh start` and shows `hs.menubar` red dot, second press calls `capture-audio.sh stop` and removes red dot, notification with duration [TS-020, TS-021, TS-023, TS-024, TS-034]
- [x] T029 [US4] Implement stealth measures in `templates/memcapture.lua` — dot-prefix temp files in `/tmp/`, no persistent UI elements, all notifications use `withdrawAfter=2` [TS-032, TS-033, TS-035, TS-036, TS-037]

**Checkpoint**: Hammerspoon Lua module complete — all three capture modalities accessible via global hotkeys with full stealth

---

## Phase 7: User Story 5 — Automated Installation (Priority: P2)

**Goal**: `install.sh` installs all capture dependencies, places scripts, configures Hammerspoon, prints permission instructions
**Independent Test**: Run installer, verify Hammerspoon/sox/whisper-cpp installed, scripts in place, directories created

### Implementation for User Story 5

- [ ] T030 [US5] Add Step 13b to `install.sh` — install Hammerspoon, sox, whisper-cpp, bats-core, shellcheck via Homebrew [TS-038]
- [ ] T031 [US5] Add Step 13c to `install.sh` — download ggml-base.en.bin whisper model from HuggingFace to `$SYS_DIR/.sys/` if not already present [TS-042]
- [ ] T032 [US5] Add Step 13d to `install.sh` — create `$SYS_DIR/files/memories/assets/` directory and `.metadata_never_index` Spotlight exclusion marker [TS-035, TS-041]
- [ ] T033 [US5] Add Step 13e to `install.sh` — sed-template and install capture scripts (capture-text.sh, capture-screen.sh, capture-audio.sh) to `$SYS_DIR/.sys/`, chmod +x [TS-039]
- [ ] T034 [US5] Add Step 13f to `install.sh` — deploy `memcapture.lua` to `~/.hammerspoon/`, add `require("memcapture")` to init.lua, set `MJShowDockIconKey` to false, reload Hammerspoon [TS-039]
- [ ] T035 [US5] Add Step 13g to `install.sh` — print macOS permission instructions (Accessibility, Screen Recording, Microphone) [TS-040]
- [ ] T036 [US5] Run shellcheck on modified `install.sh` and fix all warnings
- [ ] T037 [US5] Verify installer idempotency — re-run install does not error, preserves existing config and memories [TS-043]

**Checkpoint**: Full installer integration complete — clean install sets up entire capture system

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration testing, documentation, cleanup

- [ ] T038 [P] Update `README.md` — add Memory Capture section documenting hotkeys, usage, permissions, troubleshooting
- [ ] T039 Run end-to-end validation per `quickstart.md` test scenarios — text capture, screenshot, audio, stealth, reindex
- [ ] T040 Run shellcheck across all capture scripts and fix any remaining warnings
- [ ] T041 Verify all 43 BDD test scenarios (TS-001 through TS-043) have corresponding bats test coverage or manual verification steps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — script skeletons + shared functions
- **Phase 3 (US1 - Text)**: Depends on Phase 2 — needs capture-text.sh skeleton + shared functions
- **Phase 4 (US2 - Screenshot)**: Depends on Phase 2 — needs capture-screen.sh skeleton + shared functions
- **Phase 5 (US3 - Audio)**: Depends on Phase 2 — needs capture-audio.sh skeleton + shared functions
- **Phase 6 (US4 - Stealth/Lua)**: Depends on Phases 3, 4, 5 — Lua module invokes all three scripts
- **Phase 7 (US5 - Install)**: Depends on Phase 6 — installer deploys completed scripts + Lua module
- **Phase 8 (Polish)**: Depends on Phase 7 — all features must work before docs and final validation

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel
- **Phase 2**: T004, T005, T006 can run in parallel (different script files)
- **Phase 3-5**: After Phase 2 completes, Phases 3, 4, 5 can all start in parallel (independent scripts, independent tests)
  - Within each story: test tasks (T008/T009, T013/T014, T018/T019) run in parallel before implementation
- **Phase 6**: Sequential — single Lua file with all bindings
- **Phase 7**: T030-T035 are sequential (ordered installer steps)
- **Phase 8**: T038 can run in parallel with T039-T041

### Critical Path

```
T001 → T007 → T008/T009 → T010 → T012 → T025 → T028 → T030 → T039
(setup → shared functions → text tests → text impl → verify → Lua → audio binding → install → E2E)
```

Estimated: 41 tasks, 8 phases

### MVP Scope

**Minimum viable**: Phases 1-3 + Phase 6 (text capture hotkey binding only) + Phase 7 (install)
This delivers: `Ctrl+Opt+T` → type → Enter → markdown saved. Screenshot and audio can follow as incremental additions.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story independently completable and testable after foundational phase
- TDD MANDATORY: Write tests FIRST (red), implement (green), then refactor
- Verify bats tests fail before implementing production code
- All bash scripts must pass shellcheck before commit
- Implementation auto-commits after each task
- Stop at any checkpoint to validate story independently
