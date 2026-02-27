# Tessl Skill Review CI/CD: Jenkins

## Overview

This document provides a complete reference for implementing Tessl skill review in Jenkins pipelines. It mirrors the functionality of the GitHub Actions workflows (single-workflow and two-workflow architectures) but uses Jenkins-native concepts: declarative `pipeline {}` syntax, `withCredentials`, `changeset`/`git diff` for file detection, and Jenkins API or GitHub API for PR commenting.

The core review logic is identical across all CI platforms:

1. Detect changed `SKILL.md` files in PRs/commits
2. Run `tessl skill review --json <path>` on each
3. Calculate scores (average of descriptionJudge + contentJudge dimensions, each scored 0-3, normalized to %)
4. Compare against cached previous scores
5. Post results as PR comments with score diff indicators
6. Update cache file (`.tessl/skill-review-cache.json`) on main branch merges

## Prerequisites

- **Jenkins 2.x** with Pipeline plugin installed
- **Node.js** available on the agent (or installed via `tools` directive / `nodejs` plugin)
- **TESSL_API_KEY** stored in Jenkins credentials (type: Secret text)
- **jq** installed on the build agent (usually available on Linux agents)
- **Pipeline configured** for the repository (Multibranch Pipeline recommended)
- **GitHub Branch Source plugin** (if using GitHub for PR detection)
- **HTTP Request plugin** (optional, for posting PR comments via API)

## Architecture Options

### Trusted Contributors (Internal)

For private repositories or internal teams where all contributors are trusted:

- Single `Jenkinsfile` with direct PR commenting via GitHub API
- Simpler setup: one file, one pipeline
- Uses `withCredentials` to access `TESSL_API_KEY` and optionally a `GITHUB_TOKEN`
- PR comments posted directly from the review pipeline

### External Contributors (Public)

For public repositories accepting contributions from untrusted forks:

- **Review pipeline**: Runs skill reviews, saves results as artifacts (no secrets exposed to fork PRs)
- **Comment pipeline**: Separate trusted job that reads artifacts and posts PR comments
- Secrets are only available in the trusted comment pipeline context
- Uses Jenkins artifact archiving and downstream job triggers

## Pipeline Templates

### Jenkinsfile (Declarative Pipeline) -- Trusted / Internal

This is a complete `Jenkinsfile` for internal repositories. Place it at the root of your repository.

```groovy
pipeline {
    agent any

    // ---------------------------------------------------------------
    // Template variables -- adjust these to match your repository
    // ---------------------------------------------------------------
    environment {
        TARGET_BRANCH  = 'main'                              // {{TARGET_BRANCH}}
        CACHE_FILE     = '.tessl/skill-review-cache.json'    // {{CACHE_FILE}}
        NODE_VERSION   = '20'
    }

    triggers {
        // Rebuild on PR events and pushes (Multibranch Pipeline handles this
        // automatically; these are here for standalone Pipeline jobs).
        pollSCM('H/5 * * * *')  // fallback polling; prefer webhooks
    }

    options {
        timestamps()
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    tools {
        nodejs "${NODE_VERSION}"   // Requires NodeJS plugin; or use `sh 'nvm use 20'`
    }

    stages {

        // ==============================================================
        // Stage 1: Detect changed SKILL.md files
        // ==============================================================
        stage('Detect Changed Skills') {
            steps {
                script {
                    // Determine event type
                    def isPR = env.CHANGE_ID != null   // Multibranch sets CHANGE_ID for PRs
                    def isMain = (env.BRANCH_NAME == env.TARGET_BRANCH) && !isPR

                    if (isPR) {
                        // Compare PR branch against target branch
                        sh """
                            git fetch origin ${env.CHANGE_TARGET} --depth=50 || true
                            git diff --name-only --diff-filter=ACMR \
                                origin/${env.CHANGE_TARGET}...HEAD \
                                -- '**/SKILL.md' '**/skills/**' \
                                | grep 'SKILL\\.md\$' \
                                | xargs -I {} dirname {} \
                                | sort -u > changed_skills.txt || true
                        """
                    } else {
                        // Push to main or manual build: review all skills
                        sh """
                            find . -name "SKILL.md" \
                                -not -path "./node_modules/*" \
                                -not -path "./.git/*" \
                                | xargs -I {} dirname {} \
                                | sed 's|^\\./||' \
                                | sort -u > changed_skills.txt || true
                        """
                    }

                    env.CHANGED_SKILLS = readFile('changed_skills.txt').trim()
                    if (env.CHANGED_SKILLS) {
                        echo "Skills to review:\n${env.CHANGED_SKILLS}"
                    } else {
                        echo 'No skill changes detected.'
                    }
                }
            }
        }

        // ==============================================================
        // Stage 2: Install Tessl CLI
        // ==============================================================
        stage('Install Tessl CLI') {
            when {
                expression { env.CHANGED_SKILLS?.trim() }
            }
            steps {
                sh 'npm install -g @tessl/cli'
                sh 'tessl --version'
            }
        }

        // ==============================================================
        // Stage 3: Read Review Cache
        // ==============================================================
        stage('Read Review Cache') {
            when {
                expression { env.CHANGED_SKILLS?.trim() }
            }
            steps {
                script {
                    if (fileExists(env.CACHE_FILE)) {
                        def cacheContent = readFile(env.CACHE_FILE).trim()
                        // Validate JSON
                        def rc = sh(script: "echo '${cacheContent.replace("'", "'\\''")}' | jq empty 2>/dev/null", returnStatus: true)
                        if (rc == 0) {
                            env.REVIEW_CACHE = cacheContent
                            echo 'Cache file loaded successfully.'
                        } else {
                            echo 'WARNING: Cache file is invalid JSON, ignoring.'
                            env.REVIEW_CACHE = ''
                        }
                    } else {
                        echo 'No cache file found, will create new one.'
                        env.REVIEW_CACHE = ''
                    }
                }
            }
        }

        // ==============================================================
        // Stage 4: Run Skill Reviews
        // ==============================================================
        stage('Run Skill Reviews') {
            when {
                expression { env.CHANGED_SKILLS?.trim() }
            }
            steps {
                withCredentials([string(credentialsId: 'tessl-api-key', variable: 'TESSL_API_KEY')]) {
                    sh '''#!/bin/bash
                        set -euo pipefail

                        FAILED=0
                        TABLE="| Skill | Status | Review Score | Change |"
                        TABLE="${TABLE}\\n|-------|--------|--------------|--------|"
                        DETAILS=""

                        # Write cache content to a temp file for jq access
                        CACHE_TEMP=$(mktemp)
                        if [ -n "${REVIEW_CACHE:-}" ]; then
                            echo "$REVIEW_CACHE" > "$CACHE_TEMP"
                        else
                            echo '{"version":"1","skills":{}}' > "$CACHE_TEMP"
                        fi

                        # Temp file for new cache entries (tab-separated: path<TAB>json)
                        CACHE_ENTRIES_FILE=$(mktemp)

                        while IFS= read -r dir; do
                            [ -z "$dir" ] && continue
                            echo "========================================="
                            echo "Reviewing: $dir"
                            echo "========================================="

                            # Run review with --json flag
                            JSON_OUTPUT=$(tessl skill review --json "$dir" 2>&1) || true
                            echo "$JSON_OUTPUT"

                            # Extract JSON (skip everything before first '{')
                            JSON=$(echo "$JSON_OUTPUT" | sed -n '/{/,$p')

                            # ---- Look up previous score from cache ----
                            PREV_SCORE=""
                            PREV_DESC=""
                            PREV_CONTENT=""
                            if [ -n "${REVIEW_CACHE:-}" ]; then
                                CACHE_ENTRY=$(jq -r --arg path "$dir" '.skills[$path] // empty' "$CACHE_TEMP")
                                if [ -n "$CACHE_ENTRY" ]; then
                                    PREV_SCORE=$(echo "$CACHE_ENTRY" | jq -r '.score // empty')
                                    PREV_DESC=$(echo "$CACHE_ENTRY" | jq -r '.dimensions.description // empty')
                                    PREV_CONTENT=$(echo "$CACHE_ENTRY" | jq -r '.dimensions.content // empty')
                                fi
                            fi

                            # Validate numeric values
                            [[ -n "$PREV_SCORE" && ! "$PREV_SCORE" =~ ^[0-9]+$ ]] && PREV_SCORE=""
                            [[ -n "$PREV_DESC" && ! "$PREV_DESC" =~ ^[0-9]+$ ]] && PREV_DESC=""
                            [[ -n "$PREV_CONTENT" && ! "$PREV_CONTENT" =~ ^[0-9]+$ ]] && PREV_CONTENT=""

                            # ---- Extract fields via jq ----
                            PASSED=$(echo "$JSON" | jq -r '.validation.overallPassed // false')

                            # Calculate average score from all dimensions
                            AVG_SCORE=$(echo "$JSON" | jq -r '
                                def avg(obj): (obj.scores | to_entries | map(.value.score) | add) / (obj.scores | length) * 100 / 3;
                                (
                                    [(.descriptionJudge.evaluation | avg(.)), (.contentJudge.evaluation | avg(.))] | add / 2
                                ) | round
                            ')

                            [[ ! "$AVG_SCORE" =~ ^[0-9]+$ ]] && AVG_SCORE=0

                            # ---- Calculate diff ----
                            CHANGE=""
                            if [ -n "$PREV_SCORE" ]; then
                                DIFF=$((AVG_SCORE - PREV_SCORE))
                                if [ $DIFF -gt 0 ]; then
                                    CHANGE="🔺 +${DIFF}% (was ${PREV_SCORE}%)"
                                elif [ $DIFF -lt 0 ]; then
                                    CHANGE="🔻 ${DIFF}% (was ${PREV_SCORE}%)"
                                else
                                    CHANGE="➡️ no change"
                                fi
                            fi

                            # ---- Build status column ----
                            if [ "$PASSED" = "true" ]; then
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
                            TABLE="${TABLE}\\n| \`${DIR_DISPLAY}\` | ${STATUS} | ${AVG_SCORE}% | ${CHANGE} |"

                            # ---- Dimension scores ----
                            DESC_SCORE=$(echo "$JSON" | jq -r '
                                (.descriptionJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.descriptionJudge.evaluation.scores | length) * 3) | round
                            ')
                            CONTENT_SCORE=$(echo "$JSON" | jq -r '
                                (.contentJudge.evaluation.scores | to_entries | map(.value.score) | add) * 100 / ((.contentJudge.evaluation.scores | length) * 3) | round
                            ')
                            [[ ! "$DESC_SCORE" =~ ^[0-9]+$ ]] && DESC_SCORE=0
                            [[ ! "$CONTENT_SCORE" =~ ^[0-9]+$ ]] && CONTENT_SCORE=0

                            # ---- Detailed evaluation for collapsible section ----
                            DESC_EVAL=$(echo "$JSON" | jq -r '.descriptionJudge.evaluation |
                                "  Description: " + ((.scores | to_entries | map(.value.score) | add) * 100 / ((.scores | length) * 3) | round | tostring) + "%\n" +
                                (.scores | to_entries | map("    \\(.key): \\(.value.score)/3 - \\(.value.reasoning)") | join("\n")) + "\n\n" +
                                "    Assessment: " + .overall_assessment
                            ')
                            CONTENT_EVAL=$(echo "$JSON" | jq -r '.contentJudge.evaluation |
                                "  Content: " + ((.scores | to_entries | map(.value.score) | add) * 100 / ((.scores | length) * 3) | round | tostring) + "%\n" +
                                (.scores | to_entries | map("    \\(.key): \\(.value.score)/3 - \\(.value.reasoning)") | join("\n")) + "\n\n" +
                                "    Assessment: " + .overall_assessment
                            ')

                            SUGGESTIONS=$(echo "$JSON" | jq -r '
                                [.descriptionJudge.evaluation.suggestions // [], .contentJudge.evaluation.suggestions // []]
                                | flatten
                                | map("- " + .)
                                | join("\n")
                            ')

                            # Build collapsible details block
                            DETAILS="${DETAILS}\\n\\n<details>\\n<summary><strong>${DIR_DISPLAY}</strong> — ${AVG_SCORE}% (${STATUS#* })</summary>\\n\\n"

                            if [ -n "$PREV_SCORE" ] && [ -n "$PREV_DESC" ] && [ -n "$PREV_CONTENT" ]; then
                                DETAILS="${DETAILS}**Previous:** ${PREV_SCORE}% (Description: ${PREV_DESC}%, Content: ${PREV_CONTENT}%)\\n"
                                DETAILS="${DETAILS}**Current:**  ${AVG_SCORE}% (Description: ${DESC_SCORE}%, Content: ${CONTENT_SCORE}%)\\n\\n"
                                DETAILS="${DETAILS}---\\n\\n"
                            fi

                            DETAILS="${DETAILS}\\\`\\\`\\\`\\n${DESC_EVAL}\\n\\n${CONTENT_EVAL}\\n\\\`\\\`\\\`\\n"

                            if [ -n "$SUGGESTIONS" ]; then
                                DETAILS="${DETAILS}\\n**Suggestions:**\\n\\n${SUGGESTIONS}\\n"
                            fi
                            DETAILS="${DETAILS}\\n</details>"

                            # ---- Cache entry ----
                            CONTENT_HASH="sha256:$(sha256sum "$dir/SKILL.md" | awk '{print $1}')"

                            CACHE_ENTRY_JSON=$(jq -nc \
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

                            printf '%s\t%s\n' "$dir" "$CACHE_ENTRY_JSON" >> "$CACHE_ENTRIES_FILE"

                        done < changed_skills.txt

                        # ---- Write outputs ----
                        echo "$CACHE_ENTRIES_FILE" > cache_entries_path.txt

                        # Build full PR comment body
                        COMMENT_BODY=$(printf '%b' "<!-- tessl-skill-review -->\\n## Tessl Skill Review Results\\n\\n${TABLE}\\n\\n---\\n\\n### Detailed Review\\n${DETAILS}\\n\\n---\\n_Checks: frontmatter validity, required fields, body structure, examples, line count._\\n_Review score is informational — not used for pass/fail gating._")

                        echo "$COMMENT_BODY" > pr_comment_body.md

                        if [ "$FAILED" -eq 1 ]; then
                            echo "ERROR: One or more skills failed validation checks."
                            exit 1
                        fi
                    '''
                }
            }
        }

        // ==============================================================
        // Stage 5: Update Review Cache
        // ==============================================================
        stage('Update Review Cache') {
            when {
                expression { env.CHANGED_SKILLS?.trim() }
            }
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail

                    CACHE_FILE="${CACHE_FILE}"
                    CACHE_ENTRIES_FILE=$(cat cache_entries_path.txt)

                    mkdir -p "$(dirname "$CACHE_FILE")"

                    # Load existing cache or create new
                    if [ -f "$CACHE_FILE" ] && jq empty "$CACHE_FILE" 2>/dev/null; then
                        CACHE=$(cat "$CACHE_FILE")
                    else
                        echo "Creating new cache file..."
                        CACHE='{"version":"1","last_updated":"","skills":{}}'
                    fi

                    # Update timestamp
                    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                    CACHE=$(echo "$CACHE" | jq --arg ts "$TIMESTAMP" '.last_updated = $ts')

                    # Merge entries
                    MERGED_COUNT=0
                    while IFS=$'\t' read -r skill_path entry_json; do
                        [ -z "$skill_path" ] && continue
                        CACHE=$(echo "$CACHE" | jq --arg path "$skill_path" --argjson entry "$entry_json" \
                            '.skills[$path] = $entry')
                        MERGED_COUNT=$((MERGED_COUNT + 1))
                    done < "$CACHE_ENTRIES_FILE"

                    echo "$CACHE" | jq '.' > "$CACHE_FILE"
                    echo "Cache updated with $MERGED_COUNT entries."
                '''
            }
        }

        // ==============================================================
        // Stage 6: Post PR Comment
        // ==============================================================
        stage('Post PR Comment') {
            when {
                expression { env.CHANGE_ID != null && env.CHANGED_SKILLS?.trim() }
            }
            steps {
                script {
                    def commentBody = readFile('pr_comment_body.md').trim()

                    // -----------------------------------------------------------
                    // Option A: GitHub API with a Personal Access Token
                    //   Requires 'github-token' credential (Secret text) with
                    //   repo scope or fine-grained PR write permission.
                    // -----------------------------------------------------------
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        def prNumber = env.CHANGE_ID
                        // Extract owner/repo from the git remote URL
                        def remoteUrl = sh(script: "git remote get-url origin", returnStdout: true).trim()
                        def matcher = remoteUrl =~ /github\.com[:\\/](.+?)\\/(.+?)(?:\.git)?$/
                        def owner = matcher[0][1]
                        def repo  = matcher[0][2]

                        // Search for existing comment with our marker
                        def existingComments = sh(
                            script: """
                                curl -s -H "Authorization: token \$GITHUB_TOKEN" \
                                    -H "Accept: application/vnd.github.v3+json" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments" \
                                    | jq '[.[] | select(.body | contains("<!-- tessl-skill-review -->")) | .id] | first // empty'
                            """,
                            returnStdout: true
                        ).trim()

                        // Write comment body to a temp file for curl
                        writeFile file: 'comment_payload.json', text: groovy.json.JsonOutput.toJson([body: commentBody])

                        if (existingComments && existingComments != 'null') {
                            // Update existing comment
                            sh """
                                curl -s -X PATCH \
                                    -H "Authorization: token \$GITHUB_TOKEN" \
                                    -H "Accept: application/vnd.github.v3+json" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/comments/${existingComments}" \
                                    -d @comment_payload.json
                            """
                            echo "Updated existing PR comment #${existingComments}"
                        } else {
                            // Create new comment
                            sh """
                                curl -s -X POST \
                                    -H "Authorization: token \$GITHUB_TOKEN" \
                                    -H "Accept: application/vnd.github.v3+json" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments" \
                                    -d @comment_payload.json
                            """
                            echo "Created new PR comment on PR #${prNumber}"
                        }
                    }

                    // -----------------------------------------------------------
                    // Option B: Jenkins Pipeline (alternative -- no GitHub token)
                    //   Use the "Pipeline: GitHub" or "GitHub PR Builder" plugin
                    //   to post comments natively. Uncomment below and remove
                    //   Option A if you prefer this approach.
                    // -----------------------------------------------------------
                    // pullRequest.comment(commentBody)
                }
            }
        }

        // ==============================================================
        // Stage 7: Commit Cache (main branch only)
        // ==============================================================
        stage('Commit Cache') {
            when {
                allOf {
                    branch "${TARGET_BRANCH}"
                    expression { env.CHANGE_ID == null }  // Not a PR
                    expression { env.CHANGED_SKILLS?.trim() }
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-push-creds',
                                                  usernameVariable: 'GIT_USER',
                                                  passwordVariable: 'GIT_PASS')]) {
                    sh '''#!/bin/bash
                        set -euo pipefail

                        CACHE_FILE="${CACHE_FILE}"

                        # Check if cache actually changed
                        if git diff --quiet HEAD -- "$CACHE_FILE" 2>/dev/null; then
                            echo "Cache unchanged, skipping commit."
                            exit 0
                        fi

                        git config user.name "jenkins[bot]"
                        git config user.email "jenkins[bot]@users.noreply.jenkins.io"

                        git add "$CACHE_FILE"
                        git commit -m "chore: update skill review cache [skip ci]"

                        # Push using credentials
                        REMOTE_URL=$(git remote get-url origin)
                        # For HTTPS remotes, inject credentials
                        PUSH_URL=$(echo "$REMOTE_URL" | sed "s|https://|https://${GIT_USER}:${GIT_PASS}@|")
                        git push "$PUSH_URL" HEAD:${TARGET_BRANCH}

                        echo "Cache committed and pushed to ${TARGET_BRANCH}."
                    '''
                }
            }
        }
    }

    post {
        always {
            // Archive review artifacts for debugging
            archiveArtifacts artifacts: 'pr_comment_body.md, changed_skills.txt', allowEmptyArchive: true
            archiveArtifacts artifacts: "${CACHE_FILE}", allowEmptyArchive: true
        }
        failure {
            echo 'Skill review pipeline failed. Check the logs above for details.'
        }
        success {
            echo 'Skill review pipeline completed successfully.'
        }
    }
}
```

### Jenkinsfile (Declarative Pipeline) -- External Contributors / Public

For public repositories, split into two jobs for security isolation.

#### Job 1: Review Pipeline (`Jenkinsfile`)

This pipeline runs the review but does **not** access any secrets for PR commenting. It archives the comment body as an artifact.

```groovy
pipeline {
    agent any

    environment {
        TARGET_BRANCH  = 'main'                              // {{TARGET_BRANCH}}
        CACHE_FILE     = '.tessl/skill-review-cache.json'    // {{CACHE_FILE}}
    }

    tools {
        nodejs '20'
    }

    stages {
        stage('Detect Changed Skills') {
            steps {
                script {
                    def isPR = env.CHANGE_ID != null
                    if (isPR) {
                        sh """
                            git fetch origin ${env.CHANGE_TARGET} --depth=50 || true
                            git diff --name-only --diff-filter=ACMR \
                                origin/${env.CHANGE_TARGET}...HEAD \
                                -- '**/SKILL.md' '**/skills/**' \
                                | grep 'SKILL\\.md\$' \
                                | xargs -I {} dirname {} \
                                | sort -u > changed_skills.txt || true
                        """
                    } else {
                        sh """
                            find . -name "SKILL.md" \
                                -not -path "./node_modules/*" \
                                -not -path "./.git/*" \
                                | xargs -I {} dirname {} \
                                | sed 's|^\\./||' \
                                | sort -u > changed_skills.txt || true
                        """
                    }
                    env.CHANGED_SKILLS = readFile('changed_skills.txt').trim()
                }
            }
        }

        stage('Install Tessl CLI') {
            when { expression { env.CHANGED_SKILLS?.trim() } }
            steps {
                sh 'npm install -g @tessl/cli'
            }
        }

        stage('Run Skill Reviews') {
            when { expression { env.CHANGED_SKILLS?.trim() } }
            steps {
                // TESSL_API_KEY is safe here -- it is a review API key,
                // not a write credential for the repository.
                withCredentials([string(credentialsId: 'tessl-api-key', variable: 'TESSL_API_KEY')]) {
                    sh '''#!/bin/bash
                        # ... (same review script as the trusted pipeline above)
                        # Produces: pr_comment_body.md, cache_entries_path.txt
                        # See the trusted Jenkinsfile for the full script.
                    '''
                }
            }
        }

        stage('Update Review Cache') {
            when { expression { env.CHANGED_SKILLS?.trim() } }
            steps {
                sh '''#!/bin/bash
                    # ... (same cache update script as above)
                '''
            }
        }
    }

    post {
        always {
            // Archive artifacts for the comment job to consume
            archiveArtifacts artifacts: 'pr_comment_body.md', allowEmptyArchive: true
            archiveArtifacts artifacts: "${CACHE_FILE}", allowEmptyArchive: true

            // Write PR number for downstream job
            script {
                if (env.CHANGE_ID) {
                    writeFile file: 'pr_number.txt', text: env.CHANGE_ID
                    archiveArtifacts artifacts: 'pr_number.txt'
                }
            }
        }
    }
}
```

#### Job 2: Comment Pipeline (Separate Jenkins Job)

Create a separate Jenkins Pipeline job (e.g., "tessl-skill-review-comment") that triggers after the review pipeline completes. This job runs in a trusted context with access to the GitHub token.

```groovy
pipeline {
    agent any

    // Trigger: configure this job to be triggered by the review pipeline
    // via "Build after other projects are built" or the Parameterized
    // Trigger plugin.

    parameters {
        string(name: 'REVIEW_BUILD_NUMBER', description: 'Build number of the review pipeline')
        string(name: 'REVIEW_JOB_NAME', description: 'Full name of the review pipeline job')
    }

    stages {
        stage('Download Artifacts') {
            steps {
                // Copy artifacts from the review pipeline build
                copyArtifacts(
                    projectName: params.REVIEW_JOB_NAME,
                    selector: specific(params.REVIEW_BUILD_NUMBER),
                    filter: 'pr_comment_body.md, pr_number.txt',
                    fingerprintArtifacts: true
                )
            }
        }

        stage('Post PR Comment') {
            steps {
                script {
                    def prNumber = readFile('pr_number.txt').trim()
                    def commentBody = readFile('pr_comment_body.md').trim()

                    if (!prNumber || !commentBody) {
                        echo 'No PR number or comment body found. Skipping.'
                        return
                    }

                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        def remoteUrl = sh(script: "git remote get-url origin", returnStdout: true).trim()
                        def matcher = remoteUrl =~ /github\.com[:\\/](.+?)\\/(.+?)(?:\.git)?$/
                        def owner = matcher[0][1]
                        def repo  = matcher[0][2]

                        writeFile file: 'comment_payload.json',
                                  text: groovy.json.JsonOutput.toJson([body: commentBody])

                        // Find and update or create comment
                        def existingId = sh(
                            script: """
                                curl -s -H "Authorization: token \$GITHUB_TOKEN" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments" \
                                    | jq '[.[] | select(.body | contains("<!-- tessl-skill-review -->")) | .id] | first // empty'
                            """,
                            returnStdout: true
                        ).trim()

                        if (existingId && existingId != 'null') {
                            sh """
                                curl -s -X PATCH \
                                    -H "Authorization: token \$GITHUB_TOKEN" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/comments/${existingId}" \
                                    -d @comment_payload.json
                            """
                        } else {
                            sh """
                                curl -s -X POST \
                                    -H "Authorization: token \$GITHUB_TOKEN" \
                                    "https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments" \
                                    -d @comment_payload.json
                            """
                        }
                    }
                }
            }
        }
    }
}
```

### Template Variables

These placeholders should be adjusted when adopting the pipeline for your repository:

| Variable | Default | Description |
|----------|---------|-------------|
| `{{TARGET_BRANCH}}` | `main` | Branch that triggers cache commits on push |
| `{{TRIGGER_PATHS}}` | `**/SKILL.md`, `**/skills/**` | File path patterns that trigger the pipeline |
| `{{CACHE_FILE}}` | `.tessl/skill-review-cache.json` | Location of the score cache file in the repo |

In the Jenkinsfile, these map to:

```groovy
environment {
    TARGET_BRANCH  = 'main'                              // {{TARGET_BRANCH}}
    CACHE_FILE     = '.tessl/skill-review-cache.json'    // {{CACHE_FILE}}
}
```

For `{{TRIGGER_PATHS}}`, configure them in the Multibranch Pipeline job configuration under "Build Configuration" > "Script Path Filtering" or use the `changeset` directive in the `when` block:

```groovy
stage('Review') {
    when {
        anyOf {
            changeset '**/SKILL.md'
            changeset '**/skills/**'
        }
    }
    // ...
}
```

## Setup Instructions

### Step 1: Create the Jenkins Pipeline Job

1. In Jenkins, click **New Item**
2. Select **Multibranch Pipeline** (recommended for PR support)
3. Name it: `tessl-skill-review`
4. Under **Branch Sources**, add your Git/GitHub source
5. Under **Build Configuration**, set Script Path to `Jenkinsfile`
6. Under **Scan Multibranch Pipeline Triggers**, set an interval or configure webhooks

### Step 2: Add Required Credentials

See the Secrets Management section below for detailed instructions.

### Step 3: Place the Jenkinsfile

Copy the appropriate Jenkinsfile template (trusted or external) to the root of your repository.

### Step 4: Initialize the Cache File

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

### Step 5: Install Node.js on Agents

Either:
- Install the **NodeJS Plugin** in Jenkins and configure Node.js 20 under **Global Tool Configuration**
- Or ensure Node.js 20+ and npm are available on the build agent PATH

### Step 6: Install jq on Agents

```bash
# Debian/Ubuntu
sudo apt-get install -y jq

# RHEL/CentOS
sudo yum install -y jq

# macOS
brew install jq
```

### Step 7: Verify Setup

Trigger a manual build from the Jenkins UI and check the console output.

## Secrets Management

Jenkins stores secrets in its **Credentials** store. You need the following credentials configured:

### TESSL_API_KEY (Required)

1. Go to **Jenkins** > **Manage Jenkins** > **Credentials**
2. Select the appropriate scope (Global or Folder)
3. Click **Add Credentials**
4. Kind: **Secret text**
5. Secret: Your Tessl API key from https://tessl.io
6. ID: `tessl-api-key`
7. Description: `Tessl API key for skill review`
8. Click **OK**

Usage in pipeline:

```groovy
withCredentials([string(credentialsId: 'tessl-api-key', variable: 'TESSL_API_KEY')]) {
    sh 'tessl skill review --json path/to/skill'
}
```

### GitHub Token (Required for PR Comments)

1. Create a GitHub Personal Access Token (classic) with `repo` scope, or a fine-grained token with "Pull requests: Read and Write" permission
2. In Jenkins Credentials, add:
   - Kind: **Secret text**
   - Secret: Your GitHub token
   - ID: `github-token`
   - Description: `GitHub token for PR comments`

### Git Push Credentials (Required for Cache Commits)

For pushing cache updates to the main branch:

1. In Jenkins Credentials, add:
   - Kind: **Username with password**
   - Username: Your GitHub username or `x-access-token` (for app tokens)
   - Password: Your GitHub token
   - ID: `github-push-creds`
   - Description: `GitHub credentials for pushing cache updates`

Alternatively, if your Jenkins agent has SSH keys configured for git, you can skip this credential and use the SSH remote URL.

## Bitbucket Server / Bitbucket Cloud

If your repository is on Bitbucket instead of GitHub, adjust the PR commenting stage:

### Bitbucket Server

```groovy
stage('Post PR Comment') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'bitbucket-creds',
                                          usernameVariable: 'BB_USER',
                                          passwordVariable: 'BB_PASS')]) {
            script {
                def commentBody = readFile('pr_comment_body.md').trim()
                def prId = env.CHANGE_ID
                def project = 'YOUR_PROJECT'
                def repo = 'YOUR_REPO'
                def bbUrl = 'https://bitbucket.yourcompany.com'

                writeFile file: 'bb_comment.json',
                          text: groovy.json.JsonOutput.toJson([text: commentBody])

                sh """
                    curl -s -X POST \
                        -u "\$BB_USER:\$BB_PASS" \
                        -H "Content-Type: application/json" \
                        "${bbUrl}/rest/api/1.0/projects/${project}/repos/${repo}/pull-requests/${prId}/comments" \
                        -d @bb_comment.json
                """
            }
        }
    }
}
```

### Bitbucket Cloud

```groovy
sh """
    curl -s -X POST \
        -u "\$BB_USER:\$BB_PASS" \
        -H "Content-Type: application/json" \
        "https://api.bitbucket.org/2.0/repositories/${workspace}/${repo}/pullrequests/${prId}/comments" \
        -d @bb_comment.json
"""
```

## Troubleshooting

### Pipeline Does Not Trigger on PRs

**Cause:** Multibranch Pipeline not configured for PR discovery.

**Fix:**
1. In the Multibranch Pipeline config, under Branch Sources, ensure "Discover pull requests from origin" or "Discover pull requests from forks" is enabled
2. Verify webhooks are configured (GitHub > Settings > Webhooks > Jenkins webhook URL)
3. Click "Scan Multibranch Pipeline Now" to force discovery

### `tessl` Command Not Found

**Cause:** Node.js / npm not on PATH, or `npm install -g` failed.

**Fix:**
1. Verify Node.js is configured in **Manage Jenkins** > **Global Tool Configuration** > **NodeJS**
2. Ensure the `tools { nodejs '20' }` name matches the configured tool name exactly
3. Alternative: install in workspace instead of globally:
   ```groovy
   sh 'npm install @tessl/cli && npx tessl skill review --json ...'
   ```

### `jq: command not found`

**Cause:** jq not installed on the build agent.

**Fix:** Install jq on all agents that run this pipeline (see Step 6 above). Or use a Docker agent:

```groovy
agent {
    docker {
        image 'node:20'
        args '--entrypoint=""'
    }
}
```

Then install jq in a setup stage: `sh 'apt-get update && apt-get install -y jq'`

### PR Comment Not Appearing

**Causes:**
1. `github-token` credential not configured or has wrong permissions
2. `CHANGE_ID` is null (not a PR build)
3. GitHub API rate limit exceeded

**Fix:**
1. Verify token has `repo` scope: test with `curl -H "Authorization: token <token>" https://api.github.com/user`
2. Check Jenkins console output for curl response codes
3. Ensure the pipeline is a Multibranch Pipeline (required for `env.CHANGE_ID`)

### Cache Not Committing on Main

**Causes:**
1. `github-push-creds` credential missing or incorrect
2. Branch protection rules blocking direct pushes
3. `[skip ci]` in commit message not recognized by Jenkins (it uses different syntax)

**Fix:**
1. Test push credentials manually from the agent
2. Add the Jenkins bot user to branch protection exceptions
3. Jenkins does not natively respect `[skip ci]` -- add a `when` condition:
   ```groovy
   when {
       not {
           changelog '.*\\[skip ci\\].*'
       }
   }
   ```

### Permission Denied Pushing Cache

**Cause:** Branch protection rules on main prevent direct pushes.

**Fix:**
1. Add the service account used by Jenkins to the list of users/apps allowed to bypass branch protection
2. Or use a GitHub App token with bypass permissions
3. Or use a separate unprotected branch for cache storage and adjust `CACHE_FILE` / `TARGET_BRANCH`

### Script Security Sandbox Errors

**Cause:** Jenkins Pipeline Sandbox blocks certain Groovy methods.

**Fix:**
1. Go to **Manage Jenkins** > **In-process Script Approval**
2. Approve the pending script signatures
3. Common approvals needed: `method groovy.json.JsonOutput toJson`, regex matcher methods

## Testing

### 1. Manual Trigger Test

After setup, trigger the pipeline manually:

1. Open the Multibranch Pipeline job in Jenkins
2. Navigate to the `main` branch
3. Click **Build Now**
4. Check console output for:
   - "Skills to review:" with a list of detected skills
   - Review output from `tessl skill review --json`
   - "Cache updated with N entries"

### 2. PR Comment Test

```bash
# Create a test branch
git checkout -b test/verify-jenkins-pipeline

# Make a small change to a skill
echo "<!-- test -->" >> path/to/SKILL.md

# Push and create PR
git add path/to/SKILL.md
git commit -m "test: verify Jenkins pipeline"
git push -u origin test/verify-jenkins-pipeline
# Create PR via GitHub UI or CLI
```

Check that:
- Pipeline triggers automatically for the PR
- Console output shows review results
- PR comment appears with the review table
- Score diff shows if cache has baseline data

### 3. Cache Commit Test

```bash
# Merge the test PR into main
# Wait for the main branch pipeline to complete

git checkout main
git pull

# Verify cache was committed
git log --oneline -3
# Should see: "chore: update skill review cache [skip ci]"

# Verify cache contents
cat .tessl/skill-review-cache.json | jq '.skills | keys'
```

### 4. Score Diff Test

After the cache is populated:

```bash
# Create another branch
git checkout -b test/verify-score-diff

# Modify a previously reviewed skill
# (make a meaningful change to the SKILL.md content)
vim path/to/SKILL.md

git add path/to/SKILL.md
git commit -m "test: verify score diff"
git push -u origin test/verify-score-diff
```

The PR comment should now show score change indicators next to each reviewed skill.

## Comparison with GitHub Actions

| Feature | GitHub Actions | Jenkins |
|---------|---------------|---------|
| PR detection | `github.event_name == 'pull_request'` | `env.CHANGE_ID != null` |
| Branch detection | `github.ref == 'refs/heads/main'` | `env.BRANCH_NAME == 'main'` |
| Secrets | `${{ secrets.TESSL_API_KEY }}` | `withCredentials([...])` |
| PR comments | `peter-evans/create-or-update-comment` | GitHub API via curl |
| Artifacts | `actions/upload-artifact` | `archiveArtifacts` |
| Auto-commit | Direct `git push` with token | `git push` with credentials |
| Skip CI | `[skip ci]` in commit message | Custom `changelog` condition |
| Node.js setup | `actions/setup-node@v4` | `tools { nodejs '20' }` |
| File change detection | `paths:` trigger filter | `changeset` or `git diff` |
