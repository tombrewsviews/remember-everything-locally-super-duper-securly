# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-003
Feature: Audio Recording with Local Transcription
  As a user, I want to press a global keyboard shortcut to start recording
  audio from my microphone, press the same shortcut again to stop, and have
  the recording automatically transcribed locally.

  Background:
    Given the memory capture system is running in the background
    And the memories directory exists
    And the assets subdirectory exists
    And the local transcription engine is available

  @TS-020 @FR-008 @FR-009 @FR-012 @P2 @acceptance
  Scenario: Audio recording starts on first shortcut press
    Given no recording is currently active
    When the user presses the audio capture shortcut
    Then audio recording begins from the default microphone
    And a visual recording indicator appears in the menu bar

  @TS-021 @FR-008 @FR-010 @SC-003 @P2 @acceptance
  Scenario: Recording stops and transcription runs on second press
    Given a recording is in progress
    When the user presses the audio capture shortcut again
    Then the recording stops
    And local transcription processing begins
    And a markdown memory file is created containing the transcribed text
    And the file references the original audio file in the assets directory

  @TS-022 @FR-011 @P2 @acceptance
  Scenario: Original audio file is preserved
    Given a recording has been stopped and transcribed
    When the transcription completes
    Then the original WAV audio file is saved in the assets directory
    And the markdown memory file references the audio with a relative path

  @TS-023 @FR-015 @P2 @acceptance
  Scenario: Notification shows recording duration
    Given a recording has been stopped
    When the transcription completes
    Then a notification appears showing the recording duration in seconds
    And the notification confirms the memory was saved
    And the notification auto-dismisses within 2 seconds

  @TS-024 @FR-012 @P2 @acceptance
  Scenario: Recording indicator removed after stop
    Given a recording is in progress with menu bar indicator visible
    When the recording is stopped
    Then the menu bar recording indicator is removed

  @TS-025 @SC-003 @P2 @acceptance
  Scenario: Transcription completes within time limit
    Given a recording of 2 minutes or less has been stopped
    When the total time from stop to file creation is measured
    Then it completes within 5 seconds

  @TS-026 @SC-008 @P2 @acceptance
  Scenario: Transcription uses zero network requests
    Given a recording has been stopped
    When the transcription engine processes the audio
    Then zero network requests are made to external services

  @TS-027 @FR-008 @P2 @contract
  Scenario: capture-audio.sh start begins recording
    Given no recording PID file exists
    When the capture-audio script is called with action "start"
    Then a background audio recording process is started
    And a PID file is created
    And the script outputs "recording" to stdout
    And the script exits with code 0

  @TS-028 @FR-010 @FR-011 @P2 @contract
  Scenario: capture-audio.sh stop transcribes and saves
    Given a recording is active with a valid PID file
    When the capture-audio script is called with action "stop"
    Then the recording process is terminated
    Then the audio file is transcribed locally
    And a file matching pattern "mem_YYYYMMDD_HHMMSS_audio.md" is created
    And a file matching pattern "audio_YYYYMMDD_HHMMSS.wav" is created in assets
    And the PID file is removed
    And the script outputs the duration and file path to stdout
    And the script exits with code 0

  @TS-029 @FR-017 @P2 @contract
  Scenario: capture-audio.sh rejects start when already recording
    Given a recording is already active with a valid PID file
    When the capture-audio script is called with action "start"
    Then the script exits with code 1
    And the script outputs "Error: recording already active" to stderr

  @TS-030 @FR-017 @P2 @contract
  Scenario: capture-audio.sh rejects stop when not recording
    Given no recording PID file exists
    When the capture-audio script is called with action "stop"
    Then the script exits with code 1
    And the script outputs "Error: no active recording" to stderr

  @TS-031 @FR-017 @P2 @validation
  Scenario: Transcription failure preserves audio with fallback text
    Given a recording has been stopped
    When the transcription engine fails or produces empty output
    Then the audio file is still saved in the assets directory
    And the markdown memory file contains fallback text indicating transcription was unavailable
    And the markdown memory file references the audio file
