# Feature Specification: Memory Capture System

**Feature Branch**: `001-memory-capture`
**Created**: 2026-02-27
**Status**: Draft
**Input**: User description: "A multimodal memory capture feature for macOS using global keyboard shortcuts. Three capture modalities: Quick Text, Screenshot, and Audio Recording. All memories saved as timestamped markdown files with front-matter. Must be stealth, fast, and fully local."

## User Stories *(mandatory)*

### User Story 1 - Quick Text Capture (Priority: P1)

As a user, I want to press a global keyboard shortcut and immediately see a minimal input bar where I can type or paste text, so that I can capture a thought or piece of information in under 3 seconds without switching away from my current task.

**Why this priority**: Text capture is the most frequent memory type and the simplest to implement. It establishes the core capture-to-file pipeline that all other modalities depend on. A user who can only capture text still has a fully useful memory system.

**Independent Test**: Can be fully tested by pressing the text capture shortcut, typing a sentence, pressing Enter, and verifying a timestamped markdown file appears in the memories directory with correct content and front-matter.

**Acceptance Scenarios**:

1. **Given** the system is running in the background, **When** the user presses the text capture shortcut, **Then** a native macOS text input dialog appears within 200 milliseconds
2. **Given** the text input dialog is visible, **When** the user types "Remember to buy groceries" and clicks Save, **Then** a timestamped markdown file is created in the memories directory containing the typed text
3. **Given** the text input dialog is visible, **When** the user clicks Cancel, **Then** the dialog dismisses without creating any file
4. **Given** a text memory was just captured, **When** the file is written, **Then** a brief dark overlay notification appears and auto-dismisses within 2 seconds
5. **Given** a text memory was just saved, **When** the memory search system re-indexes, **Then** the captured text is searchable within 30 seconds

---

### User Story 2 - Screenshot Capture with Annotation (Priority: P1)

As a user, I want to press a global keyboard shortcut to select a screen region, optionally add a text note, and have the screenshot saved as a memory with its annotation, so that I can capture visual information alongside context without manual file management.

**Why this priority**: Screenshots are the second most common capture type and provide unique visual context that text alone cannot. The annotation step adds critical metadata that makes screenshots searchable and meaningful in the memory system.

**Independent Test**: Can be fully tested by pressing the screenshot shortcut, selecting a screen region, adding an optional note, and verifying both the image file and a referencing markdown file are created in the correct directories.

**Acceptance Scenarios**:

1. **Given** the system is running, **When** the user presses the screenshot capture shortcut, **Then** a semi-transparent dark overlay appears covering the main screen with centered instruction text ("Click and drag to select a region · Press Escape to cancel")
2. **Given** the selection overlay is active, **When** the user clicks and drags to select a rectangular area, **Then** a blue selection rectangle is drawn live during the drag, and on mouse-up the region is captured natively via `hs.screen:snapshot(rect)` and saved as an image file
3. **Given** a screenshot was just captured, **When** the capture completes, **Then** a native macOS dialog appears prompting for an optional text annotation
4. **Given** the annotation prompt is showing, **When** the user types a note and clicks Save, **Then** a markdown memory file is created referencing the image and containing the annotation text
5. **Given** the annotation prompt is showing, **When** the user clicks Skip (or leaves the field empty and clicks Save), **Then** a markdown memory file is created referencing the image without annotation text
6. **Given** the selection overlay is active, **When** the user presses Escape before completing a selection, **Then** the overlay is dismissed and no files are created
7. **Given** the selection overlay is active, **When** the user draws a region smaller than 10×10 pixels, **Then** the capture is cancelled with a brief notification ("selection too small")

---

### User Story 3 - Audio Recording with Local Transcription (Priority: P2)

As a user, I want to press a global keyboard shortcut to start recording audio from my microphone, press the same shortcut again to stop, and have the recording automatically transcribed locally, so that I can capture spoken thoughts hands-free without any cloud service dependency.

**Why this priority**: Audio capture enables hands-free memory creation which is valuable for brainstorming and dictation. However, it requires additional dependencies (audio recorder, transcription engine, language model) and has longer processing time, making it lower priority than text and screenshot which are simpler and faster.

**Independent Test**: Can be fully tested by pressing the audio shortcut to start recording, speaking for a few seconds, pressing the shortcut again to stop, and verifying that both an audio file and a markdown file with transcribed text appear in the correct directories.

**Acceptance Scenarios**:

1. **Given** the system is running and no recording is active, **When** the user presses the audio capture shortcut, **Then** audio recording begins from the default microphone and a visual indicator appears showing recording is active
2. **Given** a recording is in progress, **When** the user presses the audio capture shortcut again, **Then** the recording stops and transcription processing begins
3. **Given** a recording has been stopped, **When** the local transcription completes, **Then** a markdown memory file is created containing the transcribed text and referencing the original audio file
4. **Given** a recording has been stopped, **When** the transcription completes, **Then** a dark overlay notification appears showing the recording duration and confirming the memory was saved
5. **Given** the transcription engine processes the audio, **When** the total time from stop to file creation is measured, **Then** it completes within 5 seconds for recordings under 2 minutes

---

### User Story 4 - Stealth Operation (Priority: P1)

As a user, I want the memory capture system to run invisibly in the background with no persistent visual indicators, so that the system leaves minimal traces on my machine and does not clutter my workspace.

**Why this priority**: Stealth is a core constitutional principle of the project. The system must be invisible during normal operation — no dock icons, no permanent menu bar items, no Spotlight-indexed files. Transient indicators (recording dot, brief notifications) are acceptable only during active capture.

**Independent Test**: Can be fully tested by launching the system and verifying no dock icon appears, no menu bar item is visible (when not recording), the memories directory is excluded from Spotlight, and failed access attempts produce no visible output.

**Acceptance Scenarios**:

1. **Given** the system is installed and running, **When** the user checks the Dock, **Then** no icon for the capture system is visible
2. **Given** the system is running and no recording is active, **When** the user checks the menu bar, **Then** no icon or indicator for the capture system is visible
3. **Given** a recording is in progress, **When** the user checks the menu bar, **Then** a minimal recording indicator is visible, and it disappears when recording stops
4. **Given** the memories directory exists, **When** Spotlight attempts to index it, **Then** the directory and its contents are excluded from Spotlight results
5. **Given** the system is running, **When** a capture notification appears (via `hs.alert` dark overlay), **Then** it auto-dismisses within 2 seconds without requiring user interaction and without relying on macOS Notification Center permissions

---

### User Story 5 - Automated Installation (Priority: P2)

As a user, I want the memory capture components to be installed automatically as part of the existing system installer, so that I do not need to manually configure hotkey tools, audio recorders, or transcription engines.

**Why this priority**: A frictionless installation experience is important but secondary to the capture functionality itself. Users cannot use the capture system without installation, but a manual installation guide could serve as a temporary workaround.

**Independent Test**: Can be fully tested by running the installer on a clean system and verifying that all capture dependencies are installed, configuration files are placed correctly, required directories exist, and the capture shortcuts respond after installation.

**Acceptance Scenarios**:

1. **Given** a macOS machine without the capture system, **When** the user runs the installer, **Then** all required capture dependencies are installed via the system package manager
2. **Given** the installer has completed, **When** the user checks the capture configuration, **Then** all hotkey bindings are configured and the capture scripts are in place
3. **Given** the installer has completed, **When** the installer output is reviewed, **Then** clear instructions for granting required macOS permissions (Accessibility, Screen Recording, Microphone) are displayed
4. **Given** the capture system is installed, **When** the memories directory is checked, **Then** the directory structure exists with proper subdirectories for assets and Spotlight exclusion markers

---

### Edge Cases

- What happens when the user triggers a text capture shortcut while a text dialog is already visible? The `hs.dialog.textPrompt` is modal and blocks further input until dismissed, so a second invocation is naturally prevented.
- What happens when the user triggers screenshot capture but presses Escape during region selection? No files should be created and the system should return to idle state silently.
- What happens when audio recording is started but the microphone is unavailable or permissions are not granted? A brief error notification should appear and no recording should start.
- What happens when the transcription engine fails or produces empty output? The audio file should still be saved, and the markdown should note that transcription failed while preserving the audio reference.
- What happens when disk space is critically low during a capture? The system should fail gracefully with a notification rather than creating corrupt or partial files.
- What happens when the user captures text containing special characters (quotes, backticks, YAML-sensitive characters)? The content must be properly escaped in the markdown front-matter and body.
- What happens when the user triggers a new capture while a previous capture is still being processed (e.g., transcription in progress)? The new capture should proceed independently without blocking.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a global keyboard shortcut for quick text capture that works regardless of which application is in the foreground
- **FR-002**: System MUST display a native text input dialog for text entry that appears within 200 milliseconds of the shortcut press
- **FR-003**: System MUST save captured text as a timestamped markdown file with structured front-matter metadata including capture type and timestamp
- **FR-004**: System MUST provide a global keyboard shortcut for interactive screenshot region selection
- **FR-005**: System MUST save captured screenshots as image files in a dedicated assets subdirectory within the memories directory
- **FR-006**: System MUST create a markdown memory file that references each captured screenshot with a relative path
- **FR-007**: System MUST offer an optional text annotation step after each screenshot capture
- **FR-008**: System MUST provide a global keyboard shortcut that toggles audio recording on and off
- **FR-009**: System MUST record audio from the default system microphone when recording is active
- **FR-010**: System MUST transcribe recorded audio locally without transmitting audio data to any external service
- **FR-011**: System MUST save the original audio file alongside the transcription for archival purposes
- **FR-012**: System MUST display a transient visual indicator during active audio recording
- **FR-013**: System MUST trigger re-indexing of the memory database after each successful capture
- **FR-014**: System MUST operate without a persistent Dock icon, menu bar item, or Spotlight-indexed files
- **FR-015**: System MUST display brief auto-dismissing confirmation notifications after successful captures
- **FR-016**: System MUST ensure all captured files use consistent timestamped naming to prevent collisions
- **FR-017**: System MUST handle capture failures gracefully with user-visible error notifications and no partial file artifacts
- **FR-018**: System MUST be installable through the existing project installer with all dependencies resolved automatically

### Key Entities

- **Memory**: A single captured unit of information. Has a type (text, screenshot, audio), a capture timestamp, optional annotation text, and optional references to binary assets. Represented as a markdown file with structured front-matter metadata.
- **Asset**: A binary file associated with a memory (screenshot image or audio recording). Stored in a dedicated subdirectory. Referenced by relative path from the parent memory's markdown file.
- **Capture Session**: A transient interaction initiated by a keyboard shortcut. Has a modality (text, screenshot, audio), a start time, and a completion status. Produces exactly one Memory upon successful completion, or zero if cancelled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Text capture completes (shortcut press to file written) in under 1 second after the user presses Enter
- **SC-002**: Screenshot capture completes (region selected to file written) in under 1 second after annotation is confirmed
- **SC-003**: Audio transcription completes (recording stopped to file written) in under 5 seconds for recordings of 2 minutes or less
- **SC-004**: No capture flow requires more than 2 user decisions (invoke shortcut + confirm/type content)
- **SC-005**: All captured memories are searchable in the memory database within 30 seconds of capture
- **SC-006**: The capture system produces zero persistent visual artifacts (Dock icons, menu bar items, Spotlight entries) during idle operation
- **SC-007**: The installer successfully installs all capture dependencies and configuration on a clean macOS system without manual intervention beyond granting system permissions
- **SC-008**: All audio transcription occurs locally with zero network requests to external transcription services
