<!-- Sync Impact Report
Version: 1.0.0 (initial)
Modified principles: none (initial creation)
Added sections: Core Principles (5), Security Standards, Development Workflow, Governance
Removed sections: none
Follow-up TODOs: none
-->

# remember-everything-locally-super-duper-securly Constitution

## Core Principles

### I. Privacy-First

All data must remain on the user's machine by default. No feature may transmit user content to external services without explicit opt-in configuration. Cloud AI backends (OpenAI, Anthropic) are optional and require user-provided API keys. Local-only alternatives must always exist for every AI-dependent feature. Sensitive data (access codes, API keys, credentials) must never be stored in plaintext or committed to version control.

### II. Stealth by Default

The system must leave minimal observable traces on the host machine. No dock icons, no menu bar items (except transient indicators), no Spotlight indexing, no login items beyond essential background services. Failed access attempts must be indistinguishable from normal program exits. Directory structures must use dot-prefixes and Spotlight exclusion markers.

### III. Script-Native Architecture

All system components must be implementable as shell scripts, configuration files, and Homebrew-installable dependencies. No compiled binaries, no Xcode projects, no code signing required. The installer must be a single `install.sh` that handles all setup via sed-templated scripts and Homebrew packages. This ensures auditability, portability, and low maintenance burden.

### IV. Test-Driven Development

Tests must be written before production code for all new features. The Red-Green-Refactor cycle is enforced: write failing tests first, then implement until tests pass, then refactor. Test assertions are the source of truth — never modify test expectations to make failing code pass. Fix the production code instead. BDD feature files define acceptance criteria and must be generated via the IIKit workflow before implementation begins.

### V. Capture Simplicity

Memory capture must be effortless — a single keyboard shortcut invocation with minimal interaction steps. The system must never require the user to think about file formats, naming conventions, directory organization, or indexing. Capture flows must complete in under 5 seconds for all modalities. If a capture flow requires more than 2 user decisions, it is too complex.

## Security Standards

- Access codes must be stored as cryptographic hashes only (SHA-256 minimum)
- Configuration files containing secrets must have 600 permissions (owner read/write only)
- Network-facing services must bind to localhost by default
- Remote access modes must be gated behind explicit flags and rely on VPN encryption
- No unauthenticated API endpoints may be exposed beyond localhost
- Shell scripts must validate inputs and avoid command injection via proper quoting

## Development Workflow

- All features follow the IIKit phased workflow: constitution, specify, plan, checklist, testify, tasks, implement, analyze
- No production code without spec.md, plan.md, and tasks.md in place
- Security-sensitive changes require `/tessleng/security-review` before merge
- All completed implementations require `/tessleng/code-review` before marking done
- Bug fixes that do not change feature behavior may use `/iikit-bugfix` instead of the full cycle
- Shell scripts must pass shellcheck linting

## Governance

This constitution supersedes all other development practices for this project. Amendments require:
1. Explicit user approval
2. Version increment (MAJOR for principle removal/redefinition, MINOR for new principles, PATCH for clarifications)
3. Updated Sync Impact Report at the top of this file
4. Documentation of rationale for the change

All code reviews and PRs must verify compliance with these principles. If a task conflicts with a constitutional principle, stop and flag the conflict instead of proceeding.

**Version**: 1.0.0 | **Ratified**: 2026-02-27 | **Last Amended**: 2026-02-27
