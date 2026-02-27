# tessleng/code-review

A comprehensive code review tile that helps evaluate code changes for quality, identify issues, and provide actionable feedback for improvements.

## Overview

This tile provides a structured approach to reviewing code changes across multiple dimensions including code quality, functionality, maintainability, performance, security, and testing. After reviewing code, the skill guides you to offer help fixing identified issues.

The tile includes a steering rule that instructs agents to proactively review their own changes before presenting work as complete.

## Skills

### code-review

Use this skill when you need to:
- Review code changes for quality and maintainability
- Assess changes for potential bugs or issues
- Provide constructive feedback on implementation
- Identify security vulnerabilities in new code
- Suggest improvements and best practices

The skill follows a structured review process:
1. Identify what changed (unstaged, staged, or against main)
2. Evaluate changes across multiple quality dimensions
3. Provide specific, actionable feedback with severity levels
4. Highlight positive aspects
5. Offer to help implement fixes

## Steering Rules

### review-after-changes

This rule instructs the agent to proactively use the code review skill after completing changes and before marking work as complete. This ensures code quality and helps catch issues early.

The agent should review their own work:
- After implementing a feature
- After fixing bugs
- After refactoring code
- Before declaring work complete

## Usage

Invoke the skill with:
```
/code-review
```

Or ask the agent to review specific code:
```
Review my changes for security issues
```

The agent will automatically use this skill after making changes when this tile is installed.

## Contents

- `skills/code-review/SKILL.md` - Code review skill definition
- `rules/review-after-changes.md` - Steering rule for proactive reviews
- `tile.json` - Tile manifest
