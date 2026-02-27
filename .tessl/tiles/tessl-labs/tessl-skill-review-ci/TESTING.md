# Testing Instructions

After setup is complete, provide these testing instructions to the user.

## Quick Test: Manual Trigger

Test the workflow immediately without making code changes:

```bash
# Get repository info for URL construction
REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')

echo "Test the workflow now:"
echo "1. Go to: ${REPO_URL}/actions/workflows/tessl-skill-review.yml"
echo "2. Click 'Run workflow' button"
echo "3. Select branch: {{TARGET_BRANCH}}"
echo "4. Click 'Run workflow'"
echo ""
echo "What to verify:"
echo "✅ Workflow runs without errors"
echo "✅ Review scores appear in workflow summary"
echo "✅ Cache file was created/updated at: {{CACHE_FILE}}"
```

## Comprehensive Test: Pull Request Flow

Test the complete PR workflow with score diff tracking:

```
1. Create test branch:
   git checkout -b test/skill-review-setup

2. Modify a SKILL.md file (add a word to the description):
   echo "Updated for testing" >> path/to/SKILL.md

3. Commit and push:
   git add path/to/SKILL.md
   git commit -m "test: trigger skill review workflow"
   git push -u origin test/skill-review-setup

4. Create Pull Request on GitHub

5. Wait for workflow to run (check Actions tab)

6. Verify PR comment appears with:
   ✅ Review results table
   ✅ Score percentages
   ✅ Detailed evaluations in expandable sections

7. Merge the PR to {{TARGET_BRANCH}}

8. Verify cache auto-committed:
   git pull origin {{TARGET_BRANCH}}
   git log --oneline -5
   # Look for: "chore: update skill review cache [skip ci]"

9. Create another PR with same skill
   ✅ Score diff indicators appear (🔺 🔻 ➡️)
   ✅ Previous vs Current scores shown
```

## What to Look For

**Successful Setup:**
- ✅ Workflow runs without errors
- ✅ Review scores appear in output
- ✅ Cache file gets populated with skill data
- ✅ PR comments show formatted review results
- ✅ Score diff shows on subsequent runs
- ✅ Cache auto-commits to {{TARGET_BRANCH}} after PR merge

**Common Issues:**

| Issue | Solution |
|-------|----------|
| Workflow fails immediately | Check that TESSL_API_KEY is set in GitHub Secrets |
| No PR comment appears | Verify `pull-requests: write` permission in workflow |
| Cache not committing | Check that `contents: write` permission is set |
| Score diff not showing | Ensure cache file exists and has previous run data |
