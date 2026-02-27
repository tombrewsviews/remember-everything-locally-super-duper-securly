# Tessl Skill Review CI/CD: Azure DevOps

## Overview

This document provides a complete Azure DevOps Pipelines implementation for automated Tessl skill review. It mirrors the functionality of the GitHub Actions workflows (single-workflow and two-workflow variants) but uses Azure DevOps-native concepts: YAML pipelines, pipeline variables, `System.AccessToken`, and the Azure DevOps REST API for PR commenting.

The core review logic is identical across all CI platforms:

1. Detect changed `SKILL.md` files in PRs/commits
2. Run `tessl skill review --json <path>` on each changed skill
3. Calculate scores (average of descriptionJudge + contentJudge dimensions, each scored 0-3, normalized to %)
4. Compare against cached previous scores from `.tessl/skill-review-cache.json`
5. Post results as PR comments with score diff indicators
6. Update the cache file on main branch merges

## Prerequisites

- **Azure DevOps project** with Pipelines enabled
- **Git repository** hosted in Azure Repos (or external repo with service connection)
- **Node.js** available via `NodeTool@0` task (or hosted agent with Node.js pre-installed)
- **TESSL_API_KEY** stored as a secret pipeline variable (via variable group, pipeline variable, or Azure Key Vault)
- **Build Service permissions** allowing the pipeline identity to:
  - Post PR comments (Contribute to Pull Requests)
  - Push commits to main (Contribute, for cache auto-commit)
- **jq** available on the build agent (pre-installed on Microsoft-hosted Ubuntu agents)

## Architecture Options

### Internal Repositories

For internal Azure Repos where all contributors are trusted:

- **Single pipeline** (`azure-pipelines.yml`) handles review, commenting, and cache commit
- Uses `$(System.AccessToken)` for PR comments via Azure DevOps REST API
- Build Service identity pushes cache commits directly to main
- Simplest setup, recommended for most teams

### External/Fork Contributions

For projects accepting contributions from outside the organization:

- **Pipeline 1: Review** - Runs on PR validation, produces review results as a pipeline artifact
- **Pipeline 2: Comment** - Triggered by pipeline resource completion, reads artifact and posts PR comment
- Secrets are never exposed to fork PRs since the comment pipeline runs in the trusted context
- More complex but necessary when untrusted code runs in the pipeline

This document focuses on the **internal repository** approach. The external approach follows the same pattern as the GitHub Actions two-workflow variant, using Azure DevOps pipeline resources instead of `workflow_run`.

## Pipeline Templates

### azure-pipelines.yml

This is the complete pipeline definition. Place it at the root of your repository.

```yaml
# azure-pipelines.yml
# Tessl Skill Review Pipeline - Reviews SKILL.md files, posts PR comments, caches scores

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - '**/SKILL.md'
      - '**/skills/**'

pr:
  branches:
    include:
      - main
  paths:
    include:
      - '**/SKILL.md'
      - '**/skills/**'
      - 'azure-pipelines.yml'

pool:
  vmImage: 'ubuntu-latest'

variables:
  - name: CACHE_FILE
    value: '.tessl/skill-review-cache.json'
  - name: TARGET_BRANCH
    value: 'main'
  # TESSL_API_KEY should be set as a secret variable in the pipeline settings
  # or linked from a variable group / Azure Key Vault

stages:
  - stage: ReviewSkills
    displayName: 'Review Skills'
    jobs:
      - job: Review
        displayName: 'Review Changed Skills'
        steps:
          - checkout: self
            fetchDepth: 0
            persistCredentials: true

          - task: NodeTool@0
            displayName: 'Setup Node.js'
            inputs:
              versionSpec: '20.x'

          - script: |
              npm install -g @tessl/cli
            displayName: 'Install Tessl CLI'

          - script: |
              set -euo pipefail

              # Determine if this is a PR or a push to main
              if [[ -n "${SYSTEM_PULLREQUEST_PULLREQUESTID:-}" ]]; then
                echo "Running in PR context (PR #${SYSTEM_PULLREQUEST_PULLREQUESTID})"
                # Detect changed SKILL.md files between PR source and target
                TARGET_BRANCH="origin/${SYSTEM_PULLREQUEST_TARGETBRANCH##refs/heads/}"
                CHANGED_SKILLS=$(git diff --name-only --diff-filter=ACMR \
                  "${TARGET_BRANCH}"...HEAD \
                  -- '**/SKILL.md' '**/skills/**' | \
                  grep 'SKILL.md$' | \
                  xargs -I {} dirname {} | \
                  sort -u)
              else
                echo "Running on push to main or manual trigger"
                # Find all skills on push/manual
                CHANGED_SKILLS=$(find . -name "SKILL.md" \
                  -not -path "./node_modules/*" \
                  -not -path "./.git/*" | \
                  xargs -I {} dirname {} | \
                  sed 's|^\./||' | \
                  sort -u)
              fi

              if [[ -z "$CHANGED_SKILLS" ]]; then
                echo "No skill changes detected."
                echo "##vso[task.setvariable variable=SKILLS;isOutput=true]"
                exit 0
              fi

              echo "Skills to review:"
              echo "$CHANGED_SKILLS"

              # Write to file for multi-line passing between steps
              echo "$CHANGED_SKILLS" > $(Build.ArtifactStagingDirectory)/changed_skills.txt
              echo "##vso[task.setvariable variable=SKILLS;isOutput=true]found"
            displayName: 'Detect Changed Skills'
            name: detect

          - script: |
              set -euo pipefail

              CACHE_FILE="$(CACHE_FILE)"

              if [[ -f "$CACHE_FILE" ]]; then
                echo "Cache file found, loading..."
                CACHE_CONTENT=$(cat "$CACHE_FILE")
                if echo "$CACHE_CONTENT" | jq empty 2>/dev/null; then
                  echo "Cache is valid JSON"
                  echo "##vso[task.setvariable variable=CACHE_EXISTS;isOutput=true]true"
                  # Write cache to file for next step
                  cp "$CACHE_FILE" $(Build.ArtifactStagingDirectory)/review_cache.json
                else
                  echo "##vso[logissue type=warning]Cache file is invalid JSON, ignoring"
                  echo "##vso[task.setvariable variable=CACHE_EXISTS;isOutput=true]false"
                fi
              else
                echo "No cache file found, will create new one"
                echo "##vso[task.setvariable variable=CACHE_EXISTS;isOutput=true]false"
              fi
            displayName: 'Read Review Cache'
            name: cache
            condition: and(succeeded(), ne(variables['detect.SKILLS'], ''))

          - script: |
              set -euo pipefail

              SKILLS=$(cat $(Build.ArtifactStagingDirectory)/changed_skills.txt)
              CACHE_FILE="$(CACHE_FILE)"
              FAILED=0
              TABLE="| Skill | Status | Review Score | Change |"
              TABLE="${TABLE}\n|-------|--------|--------------|--------|"
              DETAILS=""

              # Load cache if available
              REVIEW_CACHE=""
              if [[ -f "$(Build.ArtifactStagingDirectory)/review_cache.json" ]]; then
                REVIEW_CACHE=$(cat "$(Build.ArtifactStagingDirectory)/review_cache.json")
              fi

              # Create temporary file for cache entries
              CACHE_FILE_TEMP=$(mktemp)

              while IFS= read -r dir; do
                [[ -z "$dir" ]] && continue
                echo "======== Reviewing $dir ========"

                # Run review with --json flag
                JSON_OUTPUT=$(tessl skill review --json "$dir" 2>&1) || true
                echo "$JSON_OUTPUT"

                # Extract JSON (skip everything before first '{')
                JSON=$(echo "$JSON_OUTPUT" | sed -n '/{/,$p')

                # Look up previous score from cache
                PREV_SCORE=""
                PREV_DESC=""
                PREV_CONTENT=""
                if [[ -n "$REVIEW_CACHE" ]]; then
                  CACHE_ENTRY=$(echo "$REVIEW_CACHE" | jq -r --arg path "$dir" '.skills[$path] // empty')
                  if [[ -n "$CACHE_ENTRY" ]]; then
                    PREV_SCORE=$(echo "$CACHE_ENTRY" | jq -r '.score // empty')
                    PREV_DESC=$(echo "$CACHE_ENTRY" | jq -r '.dimensions.description // empty')
                    PREV_CONTENT=$(echo "$CACHE_ENTRY" | jq -r '.dimensions.content // empty')
                  fi
                fi

                # Validate previous scores are numeric
                if [[ -n "$PREV_SCORE" && ! "$PREV_SCORE" =~ ^[0-9]+$ ]]; then
                  echo "##vso[logissue type=warning]Invalid previous score for $dir: $PREV_SCORE, ignoring"
                  PREV_SCORE=""
                fi
                if [[ -n "$PREV_DESC" && ! "$PREV_DESC" =~ ^[0-9]+$ ]]; then
                  PREV_DESC=""
                fi
                if [[ -n "$PREV_CONTENT" && ! "$PREV_CONTENT" =~ ^[0-9]+$ ]]; then
                  PREV_CONTENT=""
                fi

                # Extract validation status
                PASSED=$(echo "$JSON" | jq -r '.validation.overallPassed // false')

                # Calculate average score from all dimensions
                AVG_SCORE=$(echo "$JSON" | jq -r '
                  def avg(obj): (obj.scores | to_entries | map(.value.score) | add) / (obj.scores | length) * 100 / 3;
                  (
                    [(.descriptionJudge.evaluation | avg(.)), (.contentJudge.evaluation | avg(.))] | add / 2
                  ) | round
                ')

                # Validate AVG_SCORE is numeric
                if [[ ! "$AVG_SCORE" =~ ^[0-9]+$ ]]; then
                  echo "##vso[logissue type=error]Invalid average score for $dir: $AVG_SCORE"
                  AVG_SCORE=0
                fi

                # Calculate diff against previous score
                CHANGE=""
                if [[ -n "$PREV_SCORE" ]]; then
                  DIFF=$((AVG_SCORE - PREV_SCORE))
                  if [[ $DIFF -gt 0 ]]; then
                    CHANGE="🔺 +${DIFF}% (was ${PREV_SCORE}%)"
                  elif [[ $DIFF -lt 0 ]]; then
                    CHANGE="🔻 ${DIFF}% (was ${PREV_SCORE}%)"
                  else
                    CHANGE="➡️ no change"
                  fi
                fi

                # Build status column
                if [[ "$PASSED" == "true" ]]; then
                  STATUS="✅ PASSED"
                else
                  ERROR=$(echo "$JSON" | jq -r '
                    .validation.checks
                    | map(select(.status != "passed"))
                    | first
                    | .message // "Validation failed"
                  ' | cut -c1-60)
                  STATUS="❌ FAILED — ${ERROR}"
                  FAILED=1
                fi

                DIR_DISPLAY=$(echo "$dir" | tr '|' '/')
                TABLE="${TABLE}\n| \`${DIR_DISPLAY}\` | ${STATUS} | ${AVG_SCORE}% | ${CHANGE} |"

                # Calculate dimension scores
                DESC_SCORE=$(echo "$JSON" | jq -r '
                  (.descriptionJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.descriptionJudge.evaluation.scores | length) * 3) | round
                ')
                CONTENT_SCORE=$(echo "$JSON" | jq -r '
                  (.contentJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.contentJudge.evaluation.scores | length) * 3) | round
                ')

                if [[ ! "$DESC_SCORE" =~ ^[0-9]+$ ]]; then DESC_SCORE=0; fi
                if [[ ! "$CONTENT_SCORE" =~ ^[0-9]+$ ]]; then CONTENT_SCORE=0; fi

                # Extract detailed evaluations
                DESC_EVAL=$(echo "$JSON" | jq -r '.descriptionJudge.evaluation |
                  "  Description: " + ((.scores | to_entries | map(.value.score) | add) * 100 / ((.scores | length) * 3) | round | tostring) + "%\n" +
                  (.scores | to_entries | map("    \(.key): \(.value.score)/3 - \(.value.reasoning)") | join("\n")) + "\n\n" +
                  "    Assessment: " + .overall_assessment
                ')

                CONTENT_EVAL=$(echo "$JSON" | jq -r '.contentJudge.evaluation |
                  "  Content: " + ((.scores | to_entries | map(.value.score) | add) * 100 / ((.scores | length) * 3) | round | tostring) + "%\n" +
                  (.scores | to_entries | map("    \(.key): \(.value.score)/3 - \(.value.reasoning)") | join("\n")) + "\n\n" +
                  "    Assessment: " + .overall_assessment
                ')

                SUGGESTIONS=$(echo "$JSON" | jq -r '
                  [.descriptionJudge.evaluation.suggestions // [], .contentJudge.evaluation.suggestions // []]
                  | flatten
                  | map("- " + .)
                  | join("\n")
                ')

                # Build collapsible details block (Markdown)
                DETAILS="${DETAILS}\n\n<details>\n<summary><strong>${DIR_DISPLAY}</strong> — ${AVG_SCORE}% (${STATUS#* })</summary>\n\n"

                if [[ -n "$PREV_SCORE" && -n "$PREV_DESC" && -n "$PREV_CONTENT" ]]; then
                  DETAILS="${DETAILS}**Previous:** ${PREV_SCORE}% (Description: ${PREV_DESC}%, Content: ${PREV_CONTENT}%)\n"
                  DETAILS="${DETAILS}**Current:**  ${AVG_SCORE}% (Description: ${DESC_SCORE}%, Content: ${CONTENT_SCORE}%)\n\n"
                  DETAILS="${DETAILS}---\n\n"
                fi

                DETAILS="${DETAILS}\`\`\`\n${DESC_EVAL}\n\n${CONTENT_EVAL}\n\`\`\`\n"

                if [[ -n "$SUGGESTIONS" ]]; then
                  DETAILS="${DETAILS}\n**Suggestions:**\n\n${SUGGESTIONS}\n"
                fi

                DETAILS="${DETAILS}\n</details>"

                # Calculate content hash for cache
                if [[ ! -f "$dir/SKILL.md" ]]; then
                  echo "##vso[logissue type=error]SKILL.md not found for $dir"
                  continue
                fi
                CONTENT_HASH="sha256:$(sha256sum "$dir/SKILL.md" | awk '{print $1}')"

                # Build cache entry
                CACHE_ENTRY=$(jq -nc \
                  --arg score "$AVG_SCORE" \
                  --arg passed "$PASSED" \
                  --arg hash "$CONTENT_HASH" \
                  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                  --arg desc "$DESC_SCORE" \
                  --arg content "$CONTENT_SCORE" \
                  '{
                    score: ($score | tonumber),
                    validation_passed: ($passed == "true"),
                    content_hash: $hash,
                    timestamp: $ts,
                    dimensions: {
                      description: ($desc | tonumber),
                      content: ($content | tonumber)
                    }
                  }')

                printf '%s\t%s\n' "$dir" "$CACHE_ENTRY" >> "$CACHE_FILE_TEMP"

              done <<< "$SKILLS"

              # Save cache entries for the update step
              cp "$CACHE_FILE_TEMP" $(Build.ArtifactStagingDirectory)/cache_entries.tsv

              # Build PR comment body
              COMMENT_BODY=$(printf '%b' "<!-- tessl-skill-review -->\n## Tessl Skill Review Results\n\n${TABLE}\n\n---\n\n### Detailed Review\n${DETAILS}\n\n---\n_Checks: frontmatter validity, required fields, body structure, examples, line count._\n_Review score is informational — not used for pass/fail gating._")

              # Save comment body for PR commenting step
              echo "$COMMENT_BODY" > $(Build.ArtifactStagingDirectory)/comment.md

              # Write to pipeline summary (build summary markdown)
              echo "$COMMENT_BODY" > $(Build.ArtifactStagingDirectory)/summary.md
              echo "##vso[task.uploadsummary]$(Build.ArtifactStagingDirectory)/summary.md"

              if [[ "$FAILED" -eq 1 ]]; then
                echo "##vso[logissue type=error]One or more skills failed validation checks."
                exit 1
              fi
            displayName: 'Run Skill Reviews'
            name: review
            condition: and(succeeded(), ne(variables['detect.SKILLS'], ''))
            env:
              TESSL_API_KEY: $(TESSL_API_KEY)

          - script: |
              set -euo pipefail

              CACHE_FILE="$(CACHE_FILE)"
              mkdir -p "$(dirname "$CACHE_FILE")"

              # Load existing cache or create new structure
              if [[ -f "$CACHE_FILE" ]]; then
                CACHE=$(cat "$CACHE_FILE")
                if ! echo "$CACHE" | jq empty 2>/dev/null; then
                  echo "##vso[logissue type=warning]Cache file is invalid JSON, recreating"
                  CACHE='{"version":"1","last_updated":"","skills":{}}'
                fi
              else
                echo "Creating new cache file..."
                CACHE='{"version":"1","last_updated":"","skills":{}}'
              fi

              # Update timestamp
              TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
              CACHE=$(echo "$CACHE" | jq --arg ts "$TIMESTAMP" '.last_updated = $ts')

              # Merge cache updates
              MERGED_COUNT=0
              FAILED_COUNT=0

              while IFS=$'\t' read -r skill_path entry_json; do
                [[ -z "$skill_path" ]] && continue
                if NEW_CACHE=$(echo "$CACHE" | jq --arg path "$skill_path" --argjson entry "$entry_json" \
                  '.skills[$path] = $entry' 2>&1); then
                  CACHE="$NEW_CACHE"
                  MERGED_COUNT=$((MERGED_COUNT + 1))
                else
                  echo "##vso[logissue type=warning]Failed to merge cache entry for $skill_path: $NEW_CACHE"
                  FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
              done < $(Build.ArtifactStagingDirectory)/cache_entries.tsv

              # Write updated cache
              echo "$CACHE" | jq '.' > "$CACHE_FILE"

              echo "Cache updated with $MERGED_COUNT entries ($FAILED_COUNT failed)"

              # Copy to staging for artifact publish
              cp "$CACHE_FILE" $(Build.ArtifactStagingDirectory)/skill-review-cache.json
            displayName: 'Update Review Cache'
            condition: and(always(), ne(variables['detect.SKILLS'], ''))

          - task: PublishPipelineArtifact@1
            displayName: 'Publish Cache Artifact'
            inputs:
              targetPath: '$(Build.ArtifactStagingDirectory)/skill-review-cache.json'
              artifactName: 'skill-review-cache'
            condition: and(always(), ne(variables['detect.SKILLS'], ''))

          - script: |
              set -euo pipefail

              # Only post comments on PR builds
              if [[ -z "${SYSTEM_PULLREQUEST_PULLREQUESTID:-}" ]]; then
                echo "Not a PR build, skipping comment."
                exit 0
              fi

              COMMENT_FILE="$(Build.ArtifactStagingDirectory)/comment.md"
              if [[ ! -f "$COMMENT_FILE" ]]; then
                echo "No comment file found, skipping."
                exit 0
              fi

              COMMENT_BODY=$(cat "$COMMENT_FILE")
              PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID}"
              ORG_URL="${SYSTEM_COLLECTIONURI}"
              PROJECT="${SYSTEM_TEAMPROJECT}"
              REPO_ID="${BUILD_REPOSITORY_ID}"

              # URL-encode the project name for the API call
              ENCODED_PROJECT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PROJECT', safe=''))")

              API_URL="${ORG_URL}${ENCODED_PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/threads?api-version=7.1"

              echo "Posting comment to PR #${PR_ID}..."
              echo "API URL: ${API_URL}"

              # Check for existing tessl-skill-review thread to update
              EXISTING_THREADS=$(curl -s \
                -H "Authorization: Bearer ${SYSTEM_ACCESSTOKEN}" \
                -H "Content-Type: application/json" \
                "${API_URL}")

              # Find existing thread with our marker comment
              EXISTING_THREAD_ID=$(echo "$EXISTING_THREADS" | jq -r '
                .value[]
                | select(.comments[0].content | test("<!-- tessl-skill-review -->"))
                | .id
              ' 2>/dev/null | head -1)

              if [[ -n "$EXISTING_THREAD_ID" && "$EXISTING_THREAD_ID" != "null" ]]; then
                echo "Found existing review thread (ID: $EXISTING_THREAD_ID), updating..."

                # Get the comment ID of the first comment in the thread
                COMMENT_ID=$(echo "$EXISTING_THREADS" | jq -r "
                  .value[]
                  | select(.id == $EXISTING_THREAD_ID)
                  | .comments[0].id
                ")

                # Update existing comment
                UPDATE_URL="${ORG_URL}${ENCODED_PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/threads/${EXISTING_THREAD_ID}/comments/${COMMENT_ID}?api-version=7.1"

                # Escape the comment body for JSON
                ESCAPED_BODY=$(jq -Rs '.' <<< "$COMMENT_BODY")

                curl -s -X PATCH \
                  -H "Authorization: Bearer ${SYSTEM_ACCESSTOKEN}" \
                  -H "Content-Type: application/json" \
                  -d "{\"content\": ${ESCAPED_BODY}}" \
                  "${UPDATE_URL}"

                echo "Comment updated successfully."
              else
                echo "No existing review thread found, creating new one..."

                # Create new thread with comment
                ESCAPED_BODY=$(jq -Rs '.' <<< "$COMMENT_BODY")

                PAYLOAD=$(jq -nc \
                  --argjson content "$ESCAPED_BODY" \
                  '{
                    comments: [{
                      parentCommentId: 0,
                      content: $content,
                      commentType: 1
                    }],
                    status: 1
                  }')

                curl -s -X POST \
                  -H "Authorization: Bearer ${SYSTEM_ACCESSTOKEN}" \
                  -H "Content-Type: application/json" \
                  -d "$PAYLOAD" \
                  "${API_URL}"

                echo "Comment posted successfully."
              fi
            displayName: 'Post PR Comment'
            condition: and(succeeded(), ne(variables['detect.SKILLS'], ''))
            env:
              SYSTEM_ACCESSTOKEN: $(System.AccessToken)

  - stage: CommitCache
    displayName: 'Commit Cache to Main'
    dependsOn: ReviewSkills
    # Only run on push to main (not on PR builds)
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'), ne(variables['Build.Reason'], 'PullRequest'))
    jobs:
      - job: CommitCache
        displayName: 'Commit Updated Cache'
        steps:
          - checkout: self
            fetchDepth: 0
            persistCredentials: true

          - task: DownloadPipelineArtifact@2
            displayName: 'Download Cache Artifact'
            inputs:
              artifactName: 'skill-review-cache'
              targetPath: '$(Pipeline.Workspace)/cache'

          - script: |
              set -euo pipefail

              CACHE_FILE="$(CACHE_FILE)"
              mkdir -p "$(dirname "$CACHE_FILE")"

              # Move downloaded cache to correct location
              cp "$(Pipeline.Workspace)/cache/skill-review-cache.json" "$CACHE_FILE"

              # Check if cache actually changed
              if git diff --quiet HEAD -- "$CACHE_FILE" 2>/dev/null; then
                echo "Cache file unchanged, nothing to commit."
                exit 0
              fi

              echo "Cache file has changes, committing..."

              git config user.name "Azure Pipelines"
              git config user.email "azuredevops@microsoft.com"
              git add "$CACHE_FILE"
              git commit -m "chore: update skill review cache [skip ci]"

              # Push to main
              git push origin HEAD:$(TARGET_BRANCH)

              echo "Cache committed and pushed to $(TARGET_BRANCH)."
            displayName: 'Commit Cache Update'
            env:
              SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### Template Variables

The pipeline uses the following configurable values. Modify them in the `variables` section of the YAML:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TARGET_BRANCH` | `main` | Branch to commit cache updates to and base PR diffs against |
| `CACHE_FILE` | `.tessl/skill-review-cache.json` | Path to the score cache file in the repository |
| `TESSL_API_KEY` | _(secret)_ | API key for Tessl CLI authentication |

Path filters are configured in the `trigger` and `pr` sections:

| Filter | Default | Purpose |
|--------|---------|---------|
| Trigger paths | `**/SKILL.md`, `**/skills/**` | Which file changes trigger the pipeline |
| PR paths | Same + `azure-pipelines.yml` | Additional trigger on pipeline file changes |

## Setup Instructions

### Step 1: Create the Pipeline File

Copy the `azure-pipelines.yml` content above into the root of your repository.

### Step 2: Initialize the Cache File

```bash
mkdir -p .tessl
cat > .tessl/skill-review-cache.json << 'EOF'
{
  "version": "1",
  "last_updated": "",
  "skills": {}
}
EOF
git add .tessl/skill-review-cache.json
git commit -m "feat: initialize skill review cache"
git push
```

### Step 3: Create the Pipeline in Azure DevOps

1. Go to your Azure DevOps project
2. Navigate to **Pipelines** > **New Pipeline**
3. Select your repository source (Azure Repos Git, GitHub, etc.)
4. Choose **Existing Azure Pipelines YAML file**
5. Select `/azure-pipelines.yml` from the branch
6. Click **Run** (or **Save** to configure variables first)

### Step 4: Configure the TESSL_API_KEY Secret

See the **Secrets Management** section below for the recommended approach.

### Step 5: Grant Build Service Permissions

The pipeline identity needs permission to push commits and post PR comments.

1. Go to **Project Settings** > **Repositories** > select your repository
2. Under **Security**, find the build service account:
   - `<Project Name> Build Service (<Organization>)`
3. Grant these permissions:
   - **Contribute**: Allow (for cache commits)
   - **Contribute to pull requests**: Allow (for PR comments)
   - **Create branch**: Allow (optional, only if needed)

### Step 6: Enable `[skip ci]` Support

Azure DevOps respects `[skip ci]` in commit messages by default. The cache commit includes `[skip ci]` to prevent infinite pipeline triggers. Verify this is not overridden in your pipeline settings:

1. Go to **Pipelines** > select your pipeline > **Edit** > **Triggers**
2. Ensure "Override the YAML continuous integration trigger" is **unchecked**

## Secrets Management

### Option 1: Pipeline Variable (Simplest)

1. Go to **Pipelines** > select your pipeline > **Edit**
2. Click **Variables** (top-right)
3. Click **New variable**
4. Name: `TESSL_API_KEY`
5. Value: your Tessl API key
6. Check **Keep this value secret**
7. Click **OK** > **Save**

### Option 2: Variable Group (Shared Across Pipelines)

1. Go to **Pipelines** > **Library** > **+ Variable group**
2. Name: `tessl-credentials`
3. Add variable: `TESSL_API_KEY` (mark as secret)
4. Save
5. Update your pipeline YAML to reference the group:

```yaml
variables:
  - group: tessl-credentials
  - name: CACHE_FILE
    value: '.tessl/skill-review-cache.json'
  - name: TARGET_BRANCH
    value: 'main'
```

6. Authorize the pipeline to use the variable group when prompted on first run

### Option 3: Azure Key Vault (Enterprise)

1. Create a Key Vault in Azure portal
2. Add secret `TESSL-API-KEY` to the vault
3. Create a variable group linked to the Key Vault:
   - Go to **Pipelines** > **Library** > **+ Variable group**
   - Enable **Link secrets from an Azure key vault**
   - Select subscription and vault
   - Add `TESSL-API-KEY`
4. Reference in pipeline:

```yaml
variables:
  - group: tessl-keyvault-secrets
  - name: CACHE_FILE
    value: '.tessl/skill-review-cache.json'
```

Note: Key Vault secret names use hyphens, which are automatically converted to underscores in pipeline variables (`TESSL-API-KEY` becomes `TESSL_API_KEY`).

## PR Comments

### How It Works

The pipeline uses the Azure DevOps REST API to post and update PR comments via comment threads.

**API Endpoint:**
```
POST/PATCH {orgUrl}/{project}/_apis/git/repositories/{repoId}/pullRequests/{prId}/threads?api-version=7.1
```

**Authentication:** The `$(System.AccessToken)` is a predefined pipeline variable that provides an OAuth token scoped to the current pipeline run. It is automatically available without any secret configuration.

### Comment Thread Lifecycle

1. **First run on a PR**: Creates a new comment thread with the review results
2. **Subsequent runs on the same PR**: Finds the existing thread by searching for the `<!-- tessl-skill-review -->` HTML marker, then updates the first comment in that thread
3. **Different PRs**: Each PR gets its own thread

### Markdown Support

Azure DevOps PR comments support standard Markdown including:
- Tables
- Collapsible `<details>` sections
- Code blocks
- Bold, italics, emojis

This means the same comment format used in GitHub Actions works in Azure DevOps without modification.

### Troubleshooting PR Comments

If comments are not appearing:

1. **Check Build Service permissions**: The build identity needs "Contribute to pull requests" on the repository
2. **Check System.AccessToken scope**: In pipeline settings, ensure "Limit job authorization scope to current project" is appropriate for your setup
3. **Verify PR context**: The `SYSTEM_PULLREQUEST_PULLREQUESTID` variable is only populated for PR-triggered builds. Ensure the `pr:` trigger is configured (not just `trigger:`)
4. **API version**: The pipeline uses API version 7.1. If your Azure DevOps Server is older, you may need to use `6.0` or `7.0`

## Troubleshooting

### Pipeline Not Triggering on PRs

**Symptom:** Pipeline runs on pushes but not on pull requests.

**Cause:** The `pr:` section may be missing or misconfigured. Azure DevOps uses `pr:` for PR triggers (separate from `trigger:` which is for CI pushes).

**Fix:** Ensure the `pr:` block exists in your YAML:
```yaml
pr:
  branches:
    include:
      - main
  paths:
    include:
      - '**/SKILL.md'
      - '**/skills/**'
```

### Cache Not Committing

**Symptom:** Reviews run but cache never gets committed to main.

**Causes:**
1. Pipeline is running on a PR (cache commit only runs on push to main)
2. Build Service lacks "Contribute" permission on the repository
3. Branch policies block direct pushes to main

**Fix:**
- Verify the `CommitCache` stage condition: it only runs when `Build.SourceBranch` is `refs/heads/main`
- Grant "Contribute" and "Bypass policies when pushing" to the Build Service identity (if branch policies are in place)
- Check pipeline logs for the `CommitCache` stage - if it shows as "Skipped", the condition was not met

### Permission Denied on Push

**Symptom:** `TF402455: Pushes to this branch are not permitted`

**Cause:** Branch policies on main prevent the Build Service from pushing.

**Fix (choose one):**
1. Grant "Bypass policies when pushing" to the Build Service identity
2. Create a dedicated service account with bypass permissions
3. Use a Personal Access Token (PAT) instead of `System.AccessToken` for the push step

### `sha256sum` Not Found

**Symptom:** Error on macOS-based agents: `sha256sum: command not found`

**Cause:** macOS uses `shasum -a 256` instead of `sha256sum`.

**Fix:** The pipeline uses `sha256sum` which works on Microsoft-hosted Ubuntu agents. If you use macOS agents, change:
```bash
# From:
CONTENT_HASH="sha256:$(sha256sum "$dir/SKILL.md" | awk '{print $1}')"
# To:
CONTENT_HASH="sha256:$(shasum -a 256 "$dir/SKILL.md" | awk '{print $1}')"
```

### `jq` Not Found

**Symptom:** `jq: command not found`

**Cause:** The build agent does not have `jq` pre-installed.

**Fix:** Add an install step before the review:
```yaml
- script: |
    sudo apt-get update && sudo apt-get install -y jq
  displayName: 'Install jq'
```

Microsoft-hosted Ubuntu agents (`ubuntu-latest`) include `jq` by default.

### Score Diffs Not Showing

**Symptom:** PR comment shows empty Change column.

**Causes:**
1. First review (no cached baseline exists)
2. Cache file is empty or has no entry for this skill path
3. Skill path changed (rename) so it does not match the cached key

**Fix:**
- This is expected on first review after setup
- Merge a PR to main to populate the cache, then subsequent PRs will show diffs
- Check `.tessl/skill-review-cache.json` to see what skill paths are cached

### Pipeline Runs in Infinite Loop

**Symptom:** Cache commit triggers another pipeline run, which commits cache again.

**Cause:** The `[skip ci]` marker in the commit message is not being honored.

**Fix:**
1. Verify commit message includes `[skip ci]`: `"chore: update skill review cache [skip ci]"`
2. Check that YAML CI trigger override is disabled in pipeline settings
3. As a fallback, add a condition to skip when the commit message contains `[skip ci]`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - '**/SKILL.md'
      - '**/skills/**'
    exclude:
      - '.tessl/skill-review-cache.json'
```

## Testing

### 1. Verify Pipeline Setup

After creating the pipeline:

```
1. Go to Pipelines > select your pipeline
2. Click "Run pipeline"
3. Select branch: main
4. Click "Run"
5. Wait for completion

Verify:
  - Pipeline runs without errors
  - Review scores appear in the build summary
  - Cache file artifact is published
```

### 2. Test PR Comment Flow

```
1. Create a test branch:
   git checkout -b test/skill-review-setup

2. Modify a SKILL.md file:
   echo "Updated for testing" >> path/to/SKILL.md

3. Commit and push:
   git add path/to/SKILL.md
   git commit -m "test: trigger skill review pipeline"
   git push -u origin test/skill-review-setup

4. Create a Pull Request in Azure DevOps

5. Wait for the pipeline to run (check Pipelines tab or PR checks)

6. Verify:
   - Pipeline runs on the PR
   - Comment thread appears in the PR
   - Review results table is formatted correctly
   - Detailed evaluations are in collapsible sections
```

### 3. Test Cache Commit Flow

```
1. Complete (merge) the test PR to main

2. Wait for the pipeline to run on the push to main

3. Verify:
   - CommitCache stage runs successfully
   - New commit appears: "chore: update skill review cache [skip ci]"
   - .tessl/skill-review-cache.json contains skill entries
   - Pipeline does NOT trigger again from the cache commit

4. Create another PR modifying the same skill

5. Verify:
   - Score diff indicators appear (🔺 🔻 ➡️)
   - Previous vs Current scores are shown in details
```

### 4. Test Manual Trigger

```
1. Go to Pipelines > select your pipeline
2. Click "Run pipeline"
3. Select branch and click "Run"

4. Verify:
   - All skills are reviewed (not just changed ones)
   - No PR comment is posted (expected for manual runs)
   - Cache is updated
```

## Differences from GitHub Actions Implementation

| Feature | GitHub Actions | Azure DevOps |
|---------|---------------|--------------|
| PR trigger | `on: pull_request` | `pr: branches: include:` |
| Push trigger | `on: push` | `trigger: branches: include:` |
| Secrets | GitHub Secrets | Pipeline variables / Variable groups / Key Vault |
| PR comments | `peter-evans/create-or-update-comment` action | Azure DevOps REST API with `System.AccessToken` |
| Build token | `GITHUB_TOKEN` | `System.AccessToken` |
| Artifacts | `actions/upload-artifact` / `actions/download-artifact` | `PublishPipelineArtifact` / `DownloadPipelineArtifact` |
| Step outputs | `$GITHUB_OUTPUT` | `##vso[task.setvariable]` |
| Warnings/errors | `::warning::` / `::error::` | `##vso[logissue type=warning]` / `##vso[logissue type=error]` |
| Build summary | `$GITHUB_STEP_SUMMARY` | `##vso[task.uploadsummary]` |
| Cache file path | `.github/.tessl/skill-review-cache.json` | `.tessl/skill-review-cache.json` |
| `[skip ci]` | Respected by default | Respected by default |
| Node.js setup | `actions/setup-node@v4` | `NodeTool@0` |
| Checkout | `actions/checkout@v4` | `- checkout: self` |

## Changelog

### Azure DevOps Version (2026-02-25)
- Initial Azure DevOps Pipelines implementation
- Mirrors GitHub Actions single-workflow v4 functionality
- Uses Azure DevOps REST API for PR comments (create and update)
- Uses `System.AccessToken` for authentication
- Supports pipeline variables, variable groups, and Azure Key Vault for secrets
- Cache auto-commit on main branch pushes
- Score diff tracking with emoji indicators
- Build summary integration via `##vso[task.uploadsummary]`
