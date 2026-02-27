# Tessl Skill Review CI

Implements Tessl skill review CI/CD pipelines through an interactive configuration wizard. Supports GitHub Actions, Jenkins, and Azure DevOps.

## Quick Start

```bash
# Navigate to your repository
cd /path/to/your/repo

# In Claude Code, invoke:
# "Use tessl-skill-review-ci to set up skill review"
```

## What This Skill Does

1. **Validates** your environment (git repo, remote)
2. **Detects** existing pipelines and offers updates
3. **Configures** based on your preferences (CI platform, architecture)
4. **Creates** pipeline files with smart defaults
5. **Guides** you through git operations and testing

## Supported CI Platforms

| Platform | Reference | Status |
|----------|-----------|--------|
| GitHub Actions | [github-actions.md](./github-actions.md) | Full support |
| Jenkins | [jenkins.md](./jenkins.md) | Full support |
| Azure DevOps | [azure-devops.md](./azure-devops.md) | Full support |

## Pipeline Architectures

**Single-Pipeline** - For internal repos with trusted contributors. Simpler setup.

**Two-Pipeline** - For public repos with external contributors. Security isolation.

## Features

- Score diff tracking (improvement/regression indicators)
- Persistent cache in git
- Dimension-level comparisons
- Auto-commit cache updates
- Version detection and migration
- Smart defaults with customization

## After Installation

1. **Add TESSL_API_KEY** to your CI platform's secret store
2. **Test manually** using a manual trigger
3. **Test with PR** to see score diff in action
