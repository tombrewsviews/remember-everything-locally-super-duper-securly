# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-004
Feature: Stealth Operation
  As a user, I want the memory capture system to run invisibly in the
  background with no persistent visual indicators.

  @TS-032 @FR-014 @SC-006 @P1 @acceptance
  Scenario: No dock icon visible
    Given the capture system is installed and running
    When the user checks the Dock
    Then no icon for the capture system is visible

  @TS-033 @FR-014 @SC-006 @P1 @acceptance
  Scenario: No menu bar item when idle
    Given the capture system is running
    And no recording is currently active
    When the user checks the menu bar
    Then no icon or indicator for the capture system is visible

  @TS-034 @FR-012 @P1 @acceptance
  Scenario: Menu bar indicator only during recording
    Given a recording is in progress
    When the user checks the menu bar
    Then a minimal recording indicator is visible
    And the indicator disappears when recording stops

  @TS-035 @FR-014 @SC-006 @P1 @acceptance
  Scenario: Memories directory excluded from Spotlight
    Given the memories directory exists
    When Spotlight attempts to index the directory
    Then the directory and its contents are excluded from Spotlight results
    And a .metadata_never_index file exists in the memories directory

  @TS-036 @FR-015 @P1 @acceptance
  Scenario: Notifications auto-dismiss
    Given the capture system is running
    When a capture notification appears
    Then it auto-dismisses within 2 seconds
    And it does not require user interaction to dismiss

  @TS-037 @FR-014 @P1 @validation
  Scenario: Temporary files use stealth naming
    Given a capture operation is in progress
    When temporary files are created
    Then they use dot-prefixed names in the system temp directory
    And they are cleaned up after the operation completes
