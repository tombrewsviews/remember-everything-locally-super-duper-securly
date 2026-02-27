# Tessl Skill Review CI/CD: GitHub Actions

## Overview

GitHub Actions implementation of Tessl skill review with score diff tracking and persistent caching. Two architecture options: single-workflow (internal repos) and two-workflow (public repos with fork contributions).

## Prerequisites

1. **GitHub repository** with Actions enabled
2. **TESSL_API_KEY** stored in GitHub Secrets
3. **Node.js 20+** (installed via `actions/setup-node`)

## Template Variables

These placeholders are replaced with user's configuration:
- `{{TARGET_BRANCH}}` → User's target branch (default: auto-detected from GitHub remote)
- `{{TRIGGER_PATHS}}` → User's file paths (default: `**/SKILL.md`, `**/skills/**`)
- `{{CACHE_FILE}}` → User's cache location (default: `.github/.tessl/skill-review-cache.json`)

## Architecture Options

### Single-Workflow (Internal Repositories)

- All contributors are trusted (private repos, company teams)
- One workflow file: `.github/workflows/tessl-skill-review.yml`
- Direct PR commenting with `pull-requests: write` permission
- Simpler setup, faster execution

### Two-Workflow (Public Repositories)

- Accepts external contributions from untrusted forks
- Main workflow: `.github/workflows/tessl-skill-review.yml` (review + artifact)
- Comment workflow: `.github/workflows/tessl-skill-review-comment.yml` (post results)
- Uses `workflow_run` trigger with `secrets: inherit` for security

### Choosing an Architecture

- **Internal repo, trusted contributors** → Single-workflow
- **Public repo, external forks** → Two-workflow
- **Unsure** → Two-workflow (more secure, slightly more complex)

---

## Single-Workflow Template

File: `.github/workflows/tessl-skill-review.yml`

```yaml
name: Tessl Skill Review

on:
  pull_request:
    branches: [main]
    paths:
      - '**/SKILL.md'
      - '**/skills/**'
      - '.github/workflows/tessl-skill-review.yml'
  push:
    branches: [main]
    paths:
      - '**/SKILL.md'
      - '**/skills/**'
  workflow_dispatch:

permissions:
  contents: write        # Required for cache commits
  pull-requests: write   # Required for PR comments

jobs:
  review-skills:
    name: Review Skills
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Tessl CLI
        run: npm install -g @tessl/cli

      - name: Detect changed skills
        id: detect
        env:
          EVENT_NAME: ${{ github.event_name }}
          BASE_REF: ${{ github.base_ref }}
        run: |
          if [[ "$EVENT_NAME" == "pull_request" ]]; then
            CHANGED_SKILLS=$(git diff --name-only --diff-filter=ACMR \
              "origin/${BASE_REF}"...HEAD \
              -- '**/SKILL.md' '**/skills/**' | \
              grep 'SKILL.md$' | \
              xargs -I {} dirname {} | \
              sort -u)
          else
            # workflow_dispatch or push: find all skills
            CHANGED_SKILLS=$(find . -name "SKILL.md" -not -path "./node_modules/*" -not -path "./.git/*" | \
              xargs -I {} dirname {} | \
              sed 's|^\./||' | \
              sort -u)
          fi

          if [[ -z "$CHANGED_SKILLS" ]]; then
            echo "No skill changes detected."
            echo "skills=" >> "$GITHUB_OUTPUT"
          else
            echo "Skills to review:"
            echo "$CHANGED_SKILLS"
            EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
            echo "skills<<${EOF_MARKER}" >> "$GITHUB_OUTPUT"
            echo "$CHANGED_SKILLS" >> "$GITHUB_OUTPUT"
            echo "${EOF_MARKER}" >> "$GITHUB_OUTPUT"
          fi

      - name: Read review cache
        if: steps.detect.outputs.skills != ''
        id: cache
        run: |
          CACHE_FILE=".github/.tessl/skill-review-cache.json"

          if [[ -f "$CACHE_FILE" ]]; then
            echo "Cache file found, loading..."
            if CACHE_CONTENT=$(cat "$CACHE_FILE" 2>&1); then
              # Validate JSON
              if echo "$CACHE_CONTENT" | jq empty 2>/dev/null; then
                echo "cache_exists=true" >> "$GITHUB_OUTPUT"
                # Export cache to environment for review step
                EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
                echo "REVIEW_CACHE<<${EOF_MARKER}" >> "$GITHUB_ENV"
                echo "$CACHE_CONTENT" >> "$GITHUB_ENV"
                echo "${EOF_MARKER}" >> "$GITHUB_ENV"
              else
                echo "::warning::Cache file is invalid JSON, ignoring"
                echo "cache_exists=false" >> "$GITHUB_OUTPUT"
              fi
            else
              echo "::warning::Cache file exists but cannot be read: $CACHE_CONTENT"
              echo "cache_exists=false" >> "$GITHUB_OUTPUT"
            fi
          else
            echo "No cache file found, will create new one"
            echo "cache_exists=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Run skill reviews
        if: steps.detect.outputs.skills != ''
        id: review
        env:
          SKILLS: ${{ steps.detect.outputs.skills }}
          TESSL_API_KEY: ${{ secrets.TESSL_API_KEY }}
        run: |
          FAILED=0
          TABLE="| Skill | Status | Review Score | Change |"
          TABLE="${TABLE}\n|-------|--------|--------------|--------|"
          DETAILS=""

          # Create temporary file for cache entries
          CACHE_FILE_TEMP=$(mktemp)
          echo "Cache entries file: $CACHE_FILE_TEMP"

          while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            echo "::group::Reviewing $dir"

            # Run review with --json flag
            JSON_OUTPUT=$(tessl skill review --json "$dir" 2>&1)
            echo "$JSON_OUTPUT"
            echo "::endgroup::"

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

            # Validate PREV_SCORE is numeric
            if [[ -n "$PREV_SCORE" && ! "$PREV_SCORE" =~ ^[0-9]+$ ]]; then
              echo "::warning::Invalid previous score for $dir: $PREV_SCORE, ignoring"
              PREV_SCORE=""
            fi

            # Validate PREV_DESC and PREV_CONTENT are numeric
            if [[ -n "$PREV_DESC" && ! "$PREV_DESC" =~ ^[0-9]+$ ]]; then
              echo "::warning::Invalid previous description score for $dir: $PREV_DESC, ignoring"
              PREV_DESC=""
            fi
            if [[ -n "$PREV_CONTENT" && ! "$PREV_CONTENT" =~ ^[0-9]+$ ]]; then
              echo "::warning::Invalid previous content score for $dir: $PREV_CONTENT, ignoring"
              PREV_CONTENT=""
            fi

            # Extract fields via jq
            PASSED=$(echo "$JSON" | jq -r '.validation.overallPassed // false')

            # Calculate average score from all 8 dimensions
            AVG_SCORE=$(echo "$JSON" | jq -r '
              def avg(obj): (obj.scores | to_entries | map(.value.score) | add) / (obj.scores | length) * 100 / 3;
              (
                [(.descriptionJudge.evaluation | avg(.)), (.contentJudge.evaluation | avg(.))] | add / 2
              ) | round
            ')

            # Validate AVG_SCORE is numeric before arithmetic
            if [[ ! "$AVG_SCORE" =~ ^[0-9]+$ ]]; then
              echo "::error::Invalid average score calculated for $dir: $AVG_SCORE"
              AVG_SCORE=0
            fi

            # Calculate diff
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
              # Extract first validation error
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

            # Calculate dimension scores for cache and details
            DESC_SCORE=$(echo "$JSON" | jq -r '
              (.descriptionJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.descriptionJudge.evaluation.scores | length) * 3) | round
            ')
            CONTENT_SCORE=$(echo "$JSON" | jq -r '
              (.contentJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.contentJudge.evaluation.scores | length) * 3) | round
            ')

            # Validate dimension scores
            if [[ ! "$DESC_SCORE" =~ ^[0-9]+$ ]]; then
              echo "::warning::Invalid description score for $dir: $DESC_SCORE, using 0"
              DESC_SCORE=0
            fi
            if [[ ! "$CONTENT_SCORE" =~ ^[0-9]+$ ]]; then
              echo "::warning::Invalid content score for $dir: $CONTENT_SCORE, using 0"
              CONTENT_SCORE=0
            fi

            # --- Extract detailed review for collapsible section ---
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

            # Extract suggestions
            SUGGESTIONS=$(echo "$JSON" | jq -r '
              [.descriptionJudge.evaluation.suggestions // [], .contentJudge.evaluation.suggestions // []]
              | flatten
              | map("- " + .)
              | join("\n")
            ')

            # Build collapsible details block
            DETAILS="${DETAILS}\n\n<details>\n<summary><strong>${DIR_DISPLAY}</strong> — ${AVG_SCORE}% (${STATUS#* })</summary>\n\n"

            # Show score comparison if previous exists (all three must be valid)
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

            # Calculate content hash
            if [[ ! -f "$dir/SKILL.md" ]]; then
              echo "::error::SKILL.md not found for $dir"
              continue
            fi
            CONTENT_HASH=$(shasum -a 256 "$dir/SKILL.md" 2>&1)
            if [[ $? -ne 0 ]]; then
              echo "::error::Failed to calculate hash for $dir: $CONTENT_HASH"
              continue
            fi
            CONTENT_HASH="sha256:$(echo "$CONTENT_HASH" | awk '{print $1}')"

            # Build cache entry (compact to single line)
            if ! CACHE_ENTRY=$(jq -nc \
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
              }'); then
              echo "::error::Failed to build cache entry for $dir"
              continue
            fi

            # Write cache entry to file (tab-separated: path<tab>json)
            printf '%s\t%s\n' "$dir" "$CACHE_ENTRY" >> "$CACHE_FILE_TEMP"

          done <<< "$SKILLS"

          # Save cache entries file path for update step
          echo "CACHE_ENTRIES_FILE=$CACHE_FILE_TEMP" >> "$GITHUB_ENV"
          echo "Wrote $(wc -l < "$CACHE_FILE_TEMP") cache entries to $CACHE_FILE_TEMP"

          # Build PR comment body
          COMMENT_BODY=$(printf '%b' "<!-- tessl-skill-review -->\n## Tessl Skill Review Results\n\n${TABLE}\n\n---\n\n### Detailed Review\n${DETAILS}\n\n---\n_Checks: frontmatter validity, required fields, body structure, examples, line count._\n_Review score is informational — not used for pass/fail gating._")

          EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
          echo "comment<<${EOF_MARKER}" >> "$GITHUB_OUTPUT"
          echo "$COMMENT_BODY" >> "$GITHUB_OUTPUT"
          echo "${EOF_MARKER}" >> "$GITHUB_OUTPUT"

          echo "$COMMENT_BODY" >> "$GITHUB_STEP_SUMMARY"

          if [[ "$FAILED" -eq 1 ]]; then
            echo "::error::One or more skills failed validation checks."
            exit 1
          fi

      - name: Update review cache
        if: always() && steps.detect.outputs.skills != ''
        id: update-cache
        run: |
          CACHE_FILE=".github/.tessl/skill-review-cache.json"
          mkdir -p .github/.tessl

          # Load existing cache or create new structure
          if [[ -f "$CACHE_FILE" ]]; then
            if CACHE=$(cat "$CACHE_FILE" 2>&1); then
              if ! echo "$CACHE" | jq empty 2>/dev/null; then
                echo "::warning::Cache file is invalid JSON, recreating"
                CACHE='{"version":"1","last_updated":"","skills":{}}'
              fi
            else
              echo "::warning::Cache file exists but cannot be read: $CACHE"
              CACHE='{"version":"1","last_updated":"","skills":{}}'
            fi
          else
            echo "Creating new cache file..."
            CACHE='{"version":"1","last_updated":"","skills":{}}'
          fi

          # Update timestamp
          TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
          if ! CACHE=$(echo "$CACHE" | jq --arg ts "$TIMESTAMP" '.last_updated = $ts'); then
            echo "::error::Failed to update cache timestamp"
            exit 1
          fi

          # Merge cache updates (using TAB delimiter)
          MERGED_COUNT=0
          FAILED_COUNT=0

          while IFS=$'\t' read -r skill_path entry_json; do
            [[ -z "$skill_path" ]] && continue
            if NEW_CACHE=$(echo "$CACHE" | jq --arg path "$skill_path" --argjson entry "$entry_json" \
              '.skills[$path] = $entry' 2>&1); then
              CACHE="$NEW_CACHE"
              MERGED_COUNT=$((MERGED_COUNT + 1))
            else
              echo "::warning::Failed to merge cache entry for $skill_path: $NEW_CACHE"
              FAILED_COUNT=$((FAILED_COUNT + 1))
              continue
            fi
          done < "$CACHE_ENTRIES_FILE"

          # Write cache file
          if ! echo "$CACHE" | jq '.' > "$CACHE_FILE"; then
            echo "::error::Failed to write cache file"
            exit 1
          fi

          # Report accurate merge counts
          if [[ $FAILED_COUNT -gt 0 ]]; then
            echo "Cache updated with $MERGED_COUNT entries ($FAILED_COUNT failed)"
          else
            echo "Cache updated with $MERGED_COUNT entries"
          fi

      - name: Upload cache file
        if: always() && steps.update-cache.outcome == 'success'
        uses: actions/upload-artifact@v4
        with:
          name: skill-review-cache
          path: .github/.tessl/skill-review-cache.json

      - name: Find existing PR comment
        if: github.event_name == 'pull_request' && steps.detect.outputs.skills != ''
        id: find-comment
        uses: peter-evans/find-comment@v3
        with:
          issue-number: ${{ github.event.pull_request.number }}
          comment-author: 'github-actions[bot]'
          body-includes: '<!-- tessl-skill-review -->'

      - name: Post or update PR comment
        if: github.event_name == 'pull_request' && steps.detect.outputs.skills != ''
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.pull_request.number }}
          comment-id: ${{ steps.find-comment.outputs.comment-id }}
          edit-mode: replace
          body: ${{ steps.review.outputs.comment }}

  commit-cache:
    name: Commit Cache
    runs-on: ubuntu-latest
    needs: review-skills
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download cache file
        uses: actions/download-artifact@v4
        with:
          name: skill-review-cache

      - name: Move cache to correct location
        run: |
          mkdir -p .github/.tessl
          mv skill-review-cache.json .github/.tessl/skill-review-cache.json

      - name: Check for cache changes
        id: check
        run: |
          if git diff --quiet HEAD .github/.tessl/skill-review-cache.json; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Commit cache
        if: steps.check.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .github/.tessl/skill-review-cache.json
          git commit -m "chore: update skill review cache [skip ci]"
          if ! git push; then
            echo "::error::Failed to push cache update to main"
            exit 1
          fi
```

---

## Two-Workflow Template

### Main Review Workflow

File: `.github/workflows/tessl-skill-review.yml`

```yaml
name: Tessl Skill Review

on:
  pull_request:
    branches: [main]
    paths:
      - '**/SKILL.md'
      - '**/skills/**'
      - '.github/workflows/tessl-skill-review.yml'
  push:
    branches: [main]
    paths:
      - '**/SKILL.md'
      - '**/skills/**'
  workflow_dispatch:

permissions:
  contents: write  # Required for cache commits

jobs:
  review-skills:
    name: Review Skills
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Tessl CLI
        run: npm install -g @tessl/cli

      - name: Detect changed skills
        id: detect
        env:
          EVENT_NAME: ${{ github.event_name }}
          BASE_REF: ${{ github.base_ref }}
        run: |
          if [[ "$EVENT_NAME" == "pull_request" ]]; then
            CHANGED_SKILLS=$(git diff --name-only --diff-filter=ACMR \
              "origin/${BASE_REF}"...HEAD \
              -- '**/SKILL.md' '**/skills/**' | \
              grep 'SKILL.md$' | \
              xargs -I {} dirname {} | \
              sort -u)
          else
            # workflow_dispatch: find all skills
            CHANGED_SKILLS=$(find . -name "SKILL.md" -not -path "./node_modules/*" -not -path "./.git/*" | \
              xargs -I {} dirname {} | \
              sed 's|^\./||' | \
              sort -u)
          fi

          if [[ -z "$CHANGED_SKILLS" ]]; then
            echo "No skill changes detected."
            echo "skills=" >> "$GITHUB_OUTPUT"
          else
            echo "Skills to review:"
            echo "$CHANGED_SKILLS"
            EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
            echo "skills<<${EOF_MARKER}" >> "$GITHUB_OUTPUT"
            echo "$CHANGED_SKILLS" >> "$GITHUB_OUTPUT"
            echo "${EOF_MARKER}" >> "$GITHUB_OUTPUT"
          fi

      - name: Read review cache
        if: steps.detect.outputs.skills != ''
        id: cache
        run: |
          CACHE_FILE=".github/.tessl/skill-review-cache.json"

          if [[ -f "$CACHE_FILE" ]]; then
            echo "Cache file found, loading..."
            if CACHE_CONTENT=$(cat "$CACHE_FILE" 2>&1); then
              if echo "$CACHE_CONTENT" | jq empty 2>/dev/null; then
                echo "cache_exists=true" >> "$GITHUB_OUTPUT"
                EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
                echo "REVIEW_CACHE<<${EOF_MARKER}" >> "$GITHUB_ENV"
                echo "$CACHE_CONTENT" >> "$GITHUB_ENV"
                echo "${EOF_MARKER}" >> "$GITHUB_ENV"
              else
                echo "::warning::Cache file is invalid JSON, ignoring"
                echo "cache_exists=false" >> "$GITHUB_OUTPUT"
              fi
            else
              echo "::warning::Cache file exists but cannot be read: $CACHE_CONTENT"
              echo "cache_exists=false" >> "$GITHUB_OUTPUT"
            fi
          else
            echo "No cache file found, will create new one"
            echo "cache_exists=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Run skill reviews
        if: steps.detect.outputs.skills != ''
        id: review
        env:
          SKILLS: ${{ steps.detect.outputs.skills }}
          TESSL_API_KEY: ${{ secrets.TESSL_API_KEY }}
        run: |
          FAILED=0
          TABLE="| Skill | Status | Review Score | Change |"
          TABLE="${TABLE}\n|-------|--------|--------------|--------|"
          DETAILS=""

          CACHE_FILE_TEMP=$(mktemp)

          while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            echo "::group::Reviewing $dir"

            JSON_OUTPUT=$(tessl skill review --json "$dir" 2>&1)
            echo "$JSON_OUTPUT"
            echo "::endgroup::"

            JSON=$(echo "$JSON_OUTPUT" | sed -n '/{/,$p')

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

            if [[ -n "$PREV_SCORE" && ! "$PREV_SCORE" =~ ^[0-9]+$ ]]; then
              PREV_SCORE=""
            fi
            if [[ -n "$PREV_DESC" && ! "$PREV_DESC" =~ ^[0-9]+$ ]]; then
              PREV_DESC=""
            fi
            if [[ -n "$PREV_CONTENT" && ! "$PREV_CONTENT" =~ ^[0-9]+$ ]]; then
              PREV_CONTENT=""
            fi

            PASSED=$(echo "$JSON" | jq -r '.validation.overallPassed // false')

            AVG_SCORE=$(echo "$JSON" | jq -r '
              def avg(obj): (obj.scores | to_entries | map(.value.score) | add) / (obj.scores | length) * 100 / 3;
              (
                [(.descriptionJudge.evaluation | avg(.)), (.contentJudge.evaluation | avg(.))] | add / 2
              ) | round
            ')

            if [[ ! "$AVG_SCORE" =~ ^[0-9]+$ ]]; then
              AVG_SCORE=0
            fi

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

            DESC_SCORE=$(echo "$JSON" | jq -r '
              (.descriptionJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.descriptionJudge.evaluation.scores | length) * 3) | round
            ')
            CONTENT_SCORE=$(echo "$JSON" | jq -r '
              (.contentJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.contentJudge.evaluation.scores | length) * 3) | round
            ')

            if [[ ! "$DESC_SCORE" =~ ^[0-9]+$ ]]; then DESC_SCORE=0; fi
            if [[ ! "$CONTENT_SCORE" =~ ^[0-9]+$ ]]; then CONTENT_SCORE=0; fi

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

            if [[ ! -f "$dir/SKILL.md" ]]; then
              echo "::error::SKILL.md not found for $dir"
              continue
            fi
            CONTENT_HASH=$(shasum -a 256 "$dir/SKILL.md" 2>&1)
            if [[ $? -ne 0 ]]; then
              echo "::error::Failed to calculate hash for $dir: $CONTENT_HASH"
              continue
            fi
            CONTENT_HASH="sha256:$(echo "$CONTENT_HASH" | awk '{print $1}')"

            if ! CACHE_ENTRY=$(jq -nc \
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
              }'); then
              echo "::error::Failed to build cache entry for $dir"
              continue
            fi

            printf '%s\t%s\n' "$dir" "$CACHE_ENTRY" >> "$CACHE_FILE_TEMP"

          done <<< "$SKILLS"

          echo "CACHE_ENTRIES_FILE=$CACHE_FILE_TEMP" >> "$GITHUB_ENV"

          COMMENT_BODY=$(printf '%b' "<!-- tessl-skill-review -->\n## Tessl Skill Review Results\n\n${TABLE}\n\n---\n\n### Detailed Review\n${DETAILS}\n\n---\n_Checks: frontmatter validity, required fields, body structure, examples, line count._\n_Review score is informational — not used for pass/fail gating._")

          EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
          echo "comment<<${EOF_MARKER}" >> "$GITHUB_OUTPUT"
          echo "$COMMENT_BODY" >> "$GITHUB_OUTPUT"
          echo "${EOF_MARKER}" >> "$GITHUB_OUTPUT"

          echo "$COMMENT_BODY" >> "$GITHUB_STEP_SUMMARY"

          if [[ "$FAILED" -eq 1 ]]; then
            echo "::error::One or more skills failed validation checks."
            exit 1
          fi

      - name: Update review cache
        if: always() && steps.detect.outputs.skills != ''
        id: update-cache
        run: |
          CACHE_FILE=".github/.tessl/skill-review-cache.json"
          mkdir -p .github/.tessl

          if [[ -f "$CACHE_FILE" ]]; then
            if CACHE=$(cat "$CACHE_FILE" 2>&1); then
              if ! echo "$CACHE" | jq empty 2>/dev/null; then
                CACHE='{"version":"1","last_updated":"","skills":{}}'
              fi
            else
              CACHE='{"version":"1","last_updated":"","skills":{}}'
            fi
          else
            CACHE='{"version":"1","last_updated":"","skills":{}}'
          fi

          TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
          CACHE=$(echo "$CACHE" | jq --arg ts "$TIMESTAMP" '.last_updated = $ts')

          while IFS=$'\t' read -r skill_path entry_json; do
            [[ -z "$skill_path" ]] && continue
            if NEW_CACHE=$(echo "$CACHE" | jq --arg path "$skill_path" --argjson entry "$entry_json" \
              '.skills[$path] = $entry' 2>&1); then
              CACHE="$NEW_CACHE"
            fi
          done < "$CACHE_ENTRIES_FILE"

          echo "$CACHE" | jq '.' > "$CACHE_FILE"

      - name: Upload cache file
        if: always() && steps.update-cache.outcome == 'success'
        uses: actions/upload-artifact@v4
        with:
          name: skill-review-cache
          path: .github/.tessl/skill-review-cache.json

      - name: Save PR comment artifact
        if: >-
          github.event_name == 'pull_request'
          && steps.detect.outputs.skills != ''
          && (steps.review.outcome == 'success' || steps.review.outputs.comment != '')
        env:
          COMMENT_BODY: ${{ steps.review.outputs.comment }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          mkdir -p pr-comment
          echo "$PR_NUMBER" > pr-comment/pr_number
          echo "$COMMENT_BODY" > pr-comment/comment.md

      - name: Upload PR comment artifact
        if: >-
          github.event_name == 'pull_request'
          && steps.detect.outputs.skills != ''
          && (steps.review.outcome == 'success' || steps.review.outputs.comment != '')
        uses: actions/upload-artifact@v4
        with:
          name: skill-review-comment
          path: pr-comment/

  commit-cache:
    name: Commit Cache
    runs-on: ubuntu-latest
    needs: review-skills
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download cache file
        uses: actions/download-artifact@v4
        with:
          name: skill-review-cache

      - name: Move cache to correct location
        run: |
          mkdir -p .github/.tessl
          mv skill-review-cache.json .github/.tessl/skill-review-cache.json

      - name: Check for cache changes
        id: check
        run: |
          if git diff --quiet HEAD .github/.tessl/skill-review-cache.json; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Commit cache
        if: steps.check.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .github/.tessl/skill-review-cache.json
          git commit -m "chore: update skill review cache [skip ci]"
          if ! git push; then
            echo "::error::Failed to push cache update to main"
            exit 1
          fi
```

### Comment Workflow

File: `.github/workflows/tessl-skill-review-comment.yml`

```yaml
name: Post Tessl Review Comment

on:
  workflow_run:
    workflows: ["Tessl Skill Review"]
    types: [completed]

permissions:
  actions: read
  pull-requests: write

jobs:
  post-comment:
    name: Post PR Comment
    runs-on: ubuntu-latest
    if: >-
      github.event.workflow_run.event == 'pull_request'
      && github.event.workflow_run.conclusion == 'success'

    steps:
      - name: Download skill-review-comment artifact
        uses: actions/download-artifact@v4
        with:
          name: skill-review-comment
          github-token: ${{ secrets.GITHUB_TOKEN }}
          run-id: ${{ github.event.workflow_run.id }}

      - name: Read PR number and comment
        id: read
        run: |
          PR_NUMBER=$(cat pr_number)
          echo "pr_number=$PR_NUMBER" >> "$GITHUB_OUTPUT"

          EOF_MARKER=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
          echo "comment<<${EOF_MARKER}" >> "$GITHUB_OUTPUT"
          cat comment.md >> "$GITHUB_OUTPUT"
          echo "${EOF_MARKER}" >> "$GITHUB_OUTPUT"

      - name: Find existing comment
        id: find
        uses: peter-evans/find-comment@v3
        with:
          issue-number: ${{ steps.read.outputs.pr_number }}
          comment-author: 'github-actions[bot]'
          body-includes: '<!-- tessl-skill-review -->'

      - name: Create or update comment
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ steps.read.outputs.pr_number }}
          comment-id: ${{ steps.find.outputs.comment-id }}
          edit-mode: replace
          body: ${{ steps.read.outputs.comment }}
```

---

## Template Substitution Logic

When creating workflow files from these templates:

1. Read the appropriate template (single or two-workflow)
2. Replace all occurrences:
   - `branches: [main]` → `branches: [{{TARGET_BRANCH}}]`
   - `'**/SKILL.md'` and `'**/skills/**'` → User's `{{TRIGGER_PATHS}}` (formatted as YAML array)
   - `.github/.tessl/skill-review-cache.json` → `{{CACHE_FILE}}`
   - `refs/heads/main` → `refs/heads/{{TARGET_BRANCH}}`
3. Write the resulting YAML to the appropriate workflow file location

---

## Setup Instructions

### Step 1: Create Workflow File(s)

- **Single-workflow**: Create `.github/workflows/tessl-skill-review.yml`
- **Two-workflow**: Create both `.github/workflows/tessl-skill-review.yml` and `.github/workflows/tessl-skill-review-comment.yml`

### Step 2: Initialize Cache File

```bash
mkdir -p .github/.tessl
cat > .github/.tessl/skill-review-cache.json << 'EOF'
{
  "version": "1",
  "last_updated": "",
  "skills": {}
}
EOF
git add .github/.tessl/skill-review-cache.json
git commit -m "feat: initialize skill review cache"
git push
```

### Step 3: Add GitHub Secret

1. Go to repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Name: `TESSL_API_KEY`
4. Value: Your Tessl API key from https://tessl.io

### Step 4: Configure Repository Permissions (Single-Workflow Only)

1. Settings > Actions > General
2. Scroll to "Workflow permissions"
3. Select "Read and write permissions"
4. Check "Allow GitHub Actions to create and approve pull requests"

---

## Testing

### Quick Test (Manual Trigger)

```bash
gh workflow run "Tessl Skill Review" --ref main
```

### PR Comment Test

```bash
git checkout -b test/verify-workflow
echo "# Test" >> path/to/SKILL.md
git add . && git commit -m "test: verify workflow"
git push -u origin test/verify-workflow
gh pr create --title "Test workflow" --body "Testing skill review setup"
```

### Cache Commit Test

After merging a PR, verify:
```bash
git pull
git log --oneline -3
# Should see: "chore: update skill review cache [skip ci]"
```

---

## Troubleshooting

### PR Comment Not Appearing

- Verify `pull-requests: write` permission in workflow
- Check workflow logs for errors
- For two-workflow: ensure comment workflow triggers on `workflow_run`

### Cache Not Committing

- Verify `contents: write` permission
- Check `commit-cache` job status (not just `review-skills`)
- Ensure push event triggers the workflow (not just PR)

### Score Diffs Not Showing

- Expected on first review (no baseline yet)
- Check for warnings about invalid previous scores in logs
- Verify skill paths match exactly (no trailing slashes)

### Permission Denied on Push

- "refusing to allow a GitHub App to create or update workflow"
- Ensure cache commit only touches cache file, not workflow files

---

## Migration Between Architectures

### Single to Two-Workflow

1. Replace main workflow with two-workflow version
2. Add comment workflow file
3. Remove `pull-requests: write` from main workflow permissions

### Two to Single-Workflow

1. Delete `.github/workflows/tessl-skill-review-comment.yml`
2. Replace main workflow with single-workflow version
3. Configure repository to allow Actions to create PR comments

### From v1-v3 to v4

1. Replace workflow file(s) with v4 templates
2. Add `contents: write` permission (if not present)
3. Initialize cache file
4. First run populates cache; subsequent PRs show score diffs
