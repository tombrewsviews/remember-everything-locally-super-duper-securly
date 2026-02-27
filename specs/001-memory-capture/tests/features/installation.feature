# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-005
Feature: Automated Installation
  As a user, I want the memory capture components to be installed
  automatically as part of the existing system installer, so that I do
  not need to manually configure hotkey tools, audio recorders, or
  transcription engines.

  @TS-038 @FR-018 @SC-007 @P2 @acceptance
  Scenario: Capture dependencies installed via package manager
    Given a macOS machine without the capture system
    When the user runs the installer
    Then all required capture dependencies are installed via the system package manager
    And the hotkey automation tool is installed
    And the audio recording tool is installed
    And the local transcription engine is installed

  @TS-039 @FR-018 @SC-007 @P2 @acceptance
  Scenario: Hotkey bindings and scripts configured after install
    Given the installer has completed successfully
    When the user checks the capture configuration
    Then all hotkey bindings are configured
    And the text capture script is executable and in place
    And the screenshot capture script is executable and in place
    And the audio capture script is executable and in place

  @TS-040 @FR-018 @P2 @acceptance
  Scenario: Permission instructions displayed after install
    Given the installer has completed successfully
    When the installer output is reviewed
    Then clear instructions for granting Accessibility permission are displayed
    And clear instructions for granting Screen Recording permission are displayed
    And clear instructions for granting Microphone permission are displayed

  @TS-041 @FR-018 @SC-007 @P2 @acceptance
  Scenario: Memories directory structure created
    Given the capture system is installed
    When the memories directory is checked
    Then the memories directory exists
    And the assets subdirectory exists within the memories directory
    And a Spotlight exclusion marker file exists in the memories directory

  @TS-042 @FR-018 @P2 @validation
  Scenario: Transcription language model downloaded
    Given the installer has completed successfully
    When the transcription model directory is checked
    Then the English language model file exists
    And the model file size is greater than 100 megabytes

  @TS-043 @FR-018 @P2 @validation
  Scenario: Installer is idempotent on re-run
    Given the capture system is already installed
    When the user runs the installer again
    Then no errors occur during installation
    And existing configuration is preserved
    And existing memories are not deleted
