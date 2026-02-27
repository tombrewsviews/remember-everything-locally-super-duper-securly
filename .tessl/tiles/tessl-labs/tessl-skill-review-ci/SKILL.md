---
name: tessl-skill-review-ci
description: Use when setting up automated skill review pipelines, configuring CI/CD for Tessl skill scoring, adding PR checks for skills, or migrating between workflow architectures. Supports GitHub Actions, Jenkins, and Azure DevOps.
---

# Tessl Skill Review CI Installer

Implements Tessl skill review CI/CD pipelines in your repository through an interactive, configuration-first wizard. Supports multiple CI platforms.

## When to Use This Skill

Use this skill when you want to:
- Add Tessl skill review automation to a repository
- Update an existing Tessl workflow to v4 (score diff and caching)
- Migrate between single-workflow and two-workflow architectures
- Set up skill review on a different CI platform (GitHub Actions, Jenkins, Azure DevOps)

## Overview

This skill walks you through three phases:
1. **Validation & Discovery** - Checks prerequisites, detects existing pipelines
2. **Configuration** - Gathers your preferences with smart defaults
3. **Execution** - Creates files with confirmation at each step

## Supported CI Platforms

| Platform | Reference File | Status |
|----------|---------------|--------|
| GitHub Actions | [github-actions.md](./github-actions.md) | Full support |
| Jenkins | [jenkins.md](./jenkins.md) | Full support |
| Azure DevOps | [azure-devops.md](./azure-devops.md) | Full support |

## Core Review Logic (All Platforms)

Regardless of CI platform, the pipeline does the same thing:

1. **Detect** changed `SKILL.md` files (PR diff or full scan)
2. **Review** each with `tessl skill review --json <path>`
3. **Score** by averaging descriptionJudge + contentJudge dimensions (0-3 scale, normalized to %)
4. **Compare** against cached previous scores
5. **Report** results as PR comments with score diff indicators (🔺 🔻 ➡️)
6. **Cache** updated scores on main branch merges

## Pipeline Architecture Options

**Single-Pipeline** (Recommended for internal repositories)
- All contributors are trusted (private repos, company teams)
- Simpler setup with one pipeline file
- Direct PR commenting

**Two-Pipeline** (Recommended for public repositories)
- Accepts external contributions from untrusted forks
- Separates review from PR commenting for security
- Review pipeline runs in untrusted context, comment pipeline runs with secrets

---

## Phase 1: Validation & Discovery

### Step 1.1: Validate Repository

First, check that we're in a valid git repository with a remote configured.

**Actions:**
1. Run `git rev-parse --git-dir` to verify git repository
2. Run `git remote -v` to check for a remote
3. If either fails, exit with clear error message

**Error Messages:**
- Not a git repo: "Current directory is not a git repository. Please run this skill from within your repository."
- No remote: "No git remote found. Please add a remote first."

### Step 1.2: Detect Default Branch

Detect the repository's default branch from the remote.

**Actions:**
1. Run `git remote show origin | grep 'HEAD branch' | cut -d' ' -f5`
2. If that fails, fall back to `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
3. If both fail, fall back to `"main"` with a warning

**Store result in:** `DEFAULT_BRANCH` variable

### Step 1.3: Detect Existing Pipelines

Scan for existing Tessl skill review pipelines and detect their version.

**Actions:**
1. Check for GitHub Actions: `find .github/workflows -name '*tessl*skill*review*' 2>/dev/null`
2. Check for Jenkins: `find . -name 'Jenkinsfile' -exec grep -l 'tessl skill review' {} \; 2>/dev/null`
3. Check for Azure DevOps: `find . -name 'azure-pipelines*.yml' -exec grep -l 'tessl skill review' {} \; 2>/dev/null`
4. For each file found, detect version:
   - **v4**: Contains both `CACHE_ENTRIES_FILE` and `PREV_SCORE`
   - **v3**: Contains `--json` and `jq` but no cache
   - **v2**: Contains `tessl skill review` with markdown table
   - **v1**: Basic implementation

### Step 1.4: Present Discovery Results

Show user what was found and offer appropriate path forward.

**If no pipeline found:**
"No existing Tessl pipeline detected. Ready to create a new one."

**If v4 found:**
"Found Tessl skill review pipeline v4 (latest version).

Options:
A) Keep existing pipeline, skip to cache setup
B) Recreate pipeline (useful if you want to change architecture or CI platform)

Which option?"

**If v1-v3 found:**
"Found Tessl skill review pipeline v{X}.

v4 adds:
- Score diff tracking indicators
- Persistent cache in git
- Dimension-level score comparison

Update to v4?"

---

## Phase 2: Configuration

### Step 2.1: Ask CI Platform

Ask: "Which CI platform do you use?"

**Options:**
- **GitHub Actions** - GitHub-hosted runners, `.github/workflows/` YAML files
- **Jenkins** - Jenkinsfile declarative pipeline
- **Azure DevOps** - azure-pipelines.yml

**Store answer in:** `CI_PLATFORM` variable (values: "github-actions", "jenkins", "azure-devops")

### Step 2.2: Ask Pipeline Architecture

Ask: "Which pipeline architecture do you want?"

**Options:**
- **Single-pipeline (Recommended for internal repos)** - Trusted contributors, simpler setup
- **Two-pipeline (Recommended for public repos)** - External contributions, security isolation

**Store answer in:** `PIPELINE_ARCH` variable (values: "single" or "two")

### Step 2.3: Ask About Customization

Ask: "Use smart defaults, or customize settings?"

**Current defaults:**
- Target branch: `{DEFAULT_BRANCH}` (auto-detected)
- Trigger paths: `**/SKILL.md`, `**/skills/**`
- Cache location: `.tessl/skill-review-cache.json` (GitHub Actions uses `.github/.tessl/`)

**Options:**
- **Use defaults** - "Use these settings (recommended for most repos)"
- **Customize** - "Customize branch name, file paths, or cache location"

**If user chose defaults:** Set variables and skip to Step 2.5.

### Step 2.4: Gather Custom Settings (if customizing)

**Question 2.4a: Target Branch**
"Which branch should trigger the pipeline on push?"
- Default: `{DEFAULT_BRANCH}`

**Question 2.4b: Trigger File Paths**
"Which file paths should trigger the pipeline?"
- Default: `**/SKILL.md`, `**/skills/**`

**Question 2.4c: Cache File Location**
"Where should the cache file be stored?"
- Default varies by platform (see reference files)

### Step 2.5: Show Configuration Summary

Display configuration table and ask for approval:

```
Configuration Summary

| Setting           | Value                                    |
|-------------------|------------------------------------------|
| CI Platform       | {CI_PLATFORM}                            |
| Architecture      | {Single/Two}-pipeline                    |
| Target Branch     | {TARGET_BRANCH}                          |
| Trigger Paths     | {TRIGGER_PATHS}                          |
| Cache Location    | {CACHE_FILE}                             |
```

"Proceed with this configuration?"

If "Go back", restart from Step 2.1.

---

## Phase 3: Execution

**Load the appropriate reference file for template generation:**
- GitHub Actions: [github-actions.md](./github-actions.md)
- Jenkins: [jenkins.md](./jenkins.md)
- Azure DevOps: [azure-devops.md](./azure-devops.md)

Use the templates from the selected reference file, substituting `{{TARGET_BRANCH}}`, `{{TRIGGER_PATHS}}`, and `{{CACHE_FILE}}` with user's configuration.

### Step 3.1: Create/Update Pipeline File(s)

1. Create pipeline directory if needed (e.g., `.github/workflows/` for GH Actions)
2. If updating existing pipeline, create backup
3. Generate pipeline file(s) from the platform's template
4. Confirm with user: show created files

### Step 3.2: Initialize/Update Cache File

1. Check if cache file exists
2. If not, create with initial structure:
   ```json
   {
     "version": "1",
     "last_updated": "",
     "skills": {}
   }
   ```
3. Confirm with user

### Step 3.3: Remind About API Key

Display platform-specific instructions for adding `TESSL_API_KEY`:
- **GitHub Actions**: Settings > Secrets and variables > Actions > New repository secret
- **Jenkins**: Manage Jenkins > Credentials > Add credentials (Secret text)
- **Azure DevOps**: Pipelines > Library > Variable groups, or Pipeline variables (secret)

---

## Git Operations

After all files are created, ask the user what git operations to perform.

**Options:**

**A) Review changes first** - Shows `git status` and `git diff`

**B) Stage and commit** - Stage specific files, show commit message preview, commit

**C) Stage, commit, and push** - All of B plus push

**D) I'll handle git myself** - List created files and exit

### Safety Notes

- Always use `git add <specific-files>` not `git add .`
- Show commit message before committing
- Confirm before pushing to remote
- Never force push

---

## Testing Instructions

After setup is complete, refer to [TESTING.md](./TESTING.md) for verification steps.

Platform-specific testing guidance is also in each reference file.

---

## Completion

Tessl skill review pipeline setup complete!

**What you have now:**
- {Single/Two}-pipeline architecture on {CI_PLATFORM}
- Score diff tracking with persistent cache
- Auto-commit of cache updates
- PR comment integration

**Next steps:**
1. Add TESSL_API_KEY to your CI platform's secret store (if not done)
2. Run a manual/test trigger to verify setup
3. Create a test PR to see the full pipeline

**Reference files:**
- GitHub Actions: [github-actions.md](./github-actions.md)
- Jenkins: [jenkins.md](./jenkins.md)
- Azure DevOps: [azure-devops.md](./azure-devops.md)
