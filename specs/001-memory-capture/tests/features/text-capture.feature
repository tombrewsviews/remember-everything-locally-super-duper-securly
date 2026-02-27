# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-001
Feature: Quick Text Capture
  As a user, I want to press a global keyboard shortcut and immediately see a
  minimal input bar where I can type or paste text, so that I can capture a
  thought or piece of information in under 3 seconds.

  Background:
    Given the memory capture system is running in the background
    And the memories directory exists

  @TS-001 @FR-001 @FR-002 @SC-001 @P1 @acceptance
  Scenario: Input bar appears on shortcut press
    When the user presses the text capture shortcut
    Then a minimal input bar appears at the top-center of the screen within 200 milliseconds

  @TS-002 @FR-003 @SC-001 @P1 @acceptance
  Scenario: Text is saved as timestamped markdown
    Given the text input bar is visible
    When the user types "Remember to buy groceries" and presses Enter
    Then a timestamped markdown file is created in the memories directory
    And the file contains the typed text in the body
    And the file has YAML front-matter with type "text"
    And the file has YAML front-matter with a valid ISO 8601 captured timestamp
    And the file has YAML front-matter with source "capture"

  @TS-003 @FR-002 @P1 @acceptance
  Scenario: Escape dismisses without saving
    Given the text input bar is visible
    When the user presses Escape
    Then the input bar dismisses
    And no new file is created in the memories directory

  @TS-004 @FR-015 @P1 @acceptance
  Scenario: Confirmation notification after text capture
    Given a text memory was just captured successfully
    When the file is written to disk
    Then a brief confirmation notification appears with title "Memory saved"
    And the notification auto-dismisses within 2 seconds

  @TS-005 @FR-013 @SC-005 @P1 @acceptance
  Scenario: Captured text becomes searchable
    Given a text memory was just saved
    When the memory search system re-indexes
    Then the captured text is searchable within 30 seconds

  @TS-006 @FR-016 @P1 @contract
  Scenario: capture-text.sh creates correctly named file
    Given the capture-text script receives "Test content" as input
    When the script executes
    Then a file matching pattern "mem_YYYYMMDD_HHMMSS_text.md" is created
    And the script exits with code 0
    And the script outputs the absolute path of the created file

  @TS-007 @FR-017 @P1 @contract
  Scenario: capture-text.sh rejects empty input
    Given the capture-text script receives empty input
    When the script executes
    Then the script exits with code 1
    And the script outputs "Error: empty text" to stderr
    And no file is created in the memories directory

  @TS-008 @FR-003 @P2 @validation
  Scenario: Special characters are properly escaped in front-matter
    Given the capture-text script receives text containing quotes and backticks
    When the script executes
    Then the YAML front-matter is valid and parseable
    And the body text preserves the original special characters

  @TS-009 @FR-002 @SC-004 @P1 @acceptance
  Scenario: Duplicate shortcut press focuses existing bar
    Given the text input bar is already visible
    When the user presses the text capture shortcut again
    Then the existing input bar receives focus
    And no second input bar is opened
