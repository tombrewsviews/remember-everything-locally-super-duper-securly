# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-002
Feature: Screenshot Capture with Annotation
  As a user, I want to press a global keyboard shortcut to select a screen
  region, optionally add a text note, and have the screenshot saved as a
  memory with its annotation.

  Background:
    Given the memory capture system is running in the background
    And the memories directory exists
    And the assets subdirectory exists

  @TS-010 @FR-004 @P1 @acceptance
  Scenario: Region selection mode activates on shortcut
    When the user presses the screenshot capture shortcut
    Then the screen enters interactive region selection mode

  @TS-011 @FR-005 @SC-002 @P1 @acceptance
  Scenario: Selected region is saved as image asset
    Given region selection is active
    When the user selects a rectangular area
    Then the selected region is captured as a PNG file in the assets directory
    And the PNG file has a non-zero size

  @TS-012 @FR-007 @P1 @acceptance
  Scenario: Annotation prompt appears after screenshot
    Given a screenshot was just taken
    When the capture completes successfully
    Then a minimal input bar appears prompting for an optional text annotation

  @TS-013 @FR-006 @FR-007 @SC-002 @P1 @acceptance
  Scenario: Screenshot saved with annotation
    Given the annotation prompt is showing after a screenshot
    When the user types "Error dialog from build system" and presses Enter
    Then a markdown memory file is created with type "screenshot"
    And the markdown file references the screenshot image with a relative path
    And the markdown file contains the annotation text
    And the YAML front-matter includes the annotation field

  @TS-014 @FR-006 @P1 @acceptance
  Scenario: Screenshot saved without annotation
    Given the annotation prompt is showing after a screenshot
    When the user presses Enter without typing any text
    Then a markdown memory file is created with type "screenshot"
    And the markdown file references the screenshot image with a relative path
    And the markdown file does not contain annotation text

  @TS-015 @FR-004 @P1 @acceptance
  Scenario: Region selection cancelled with Escape
    Given region selection is active
    When the user presses Escape before selecting a region
    Then the capture is cancelled
    And no files are created in the memories directory
    And no files are created in the assets directory

  @TS-016 @FR-016 @P1 @contract
  Scenario: capture-screen.sh creates correctly named files
    Given a temporary screenshot file exists at a known path
    When the capture-screen script is called with the temp path and annotation "Test note"
    Then a file matching pattern "mem_YYYYMMDD_HHMMSS_screenshot.md" is created in memories
    And a file matching pattern "scr_YYYYMMDD_HHMMSS.png" is created in assets
    And the temporary file is removed
    And the script exits with code 0

  @TS-017 @FR-017 @P1 @contract
  Scenario: capture-screen.sh rejects missing image
    Given the capture-screen script is called with a non-existent image path
    When the script executes
    Then the script exits with code 1
    And the script outputs "Error: image not found" to stderr

  @TS-018 @FR-017 @P1 @contract
  Scenario: capture-screen.sh rejects zero-size image
    Given a temporary screenshot file exists but has zero bytes
    When the capture-screen script is called with that path
    Then the script exits with code 1
    And the script outputs "Error: image is empty" to stderr

  @TS-019 @FR-006 @P2 @validation
  Scenario: Screenshot markdown references image with relative path
    Given a screenshot memory file was created
    When the file content is inspected
    Then the image reference uses a relative path starting with "assets/"
    And the referenced image file exists at that relative path
