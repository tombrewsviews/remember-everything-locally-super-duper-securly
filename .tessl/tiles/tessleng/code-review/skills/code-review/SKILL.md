---
name: code-review
description: Review code changes for quality, maintainability, and potential improvements. Reviews unstaged changes or changes against main branch. Use when asked to review code, assess code quality, or provide feedback on implementation.
---

# Code Review Skill

Perform a comprehensive code review of changes to assess quality, identify issues, and suggest improvements.

## Determining What to Review

### Step 1: Identify the Changes

Run the following commands to determine what code to review:

1. **Check for unstaged changes first:**
   ```bash
   git diff
   ```
   If there are unstaged changes, review these.

2. **If no unstaged changes, check staged changes:**
   ```bash
   git diff --cached
   ```
   If there are staged changes, review these.

3. **If no staged or unstaged changes, compare against main:**
   ```bash
   git diff main...HEAD
   ```
   Review all changes in the current branch compared to main.

4. **If on main branch with no changes:**
   Ask the user what they'd like to review, or inform them there are no changes to review.

### Step 2: List the Changed Files

Once you've identified what to review, list the files that have changed:

```bash
git diff --name-only [appropriate-flags-from-above]
```

Focus your review on these changed files only.

## Review Process

### 1. Understand the Context

Before reviewing the changes:

1. **Read the changed code** - Use `git diff` to see exactly what was added, modified, or removed
2. **Understand the scope** - What is being changed and why?
3. **Read surrounding context** - Look at the full files to understand how changes fit into existing code
4. **Check commit messages** - If available, review commit messages to understand intent
5. **Note the language and framework** - Understand the idioms and best practices for the technology stack

### 2. Review Categories

Evaluate the changes across these dimensions:

#### Code Quality
- **Readability**: Is the new/changed code easy to understand? Are variable and function names clear and descriptive?
- **Simplicity**: Is the code as simple as it can be? Are there unnecessary abstractions or complexity?
- **Consistency**: Do the changes follow the existing patterns and conventions in the codebase?
- **DRY Principle**: Does the change introduce duplicated code that could be consolidated?

#### Functionality
- **Correctness**: Do the changes do what they're supposed to do? Are there logical errors or edge cases not handled?
- **Error Handling**: Are errors caught and handled appropriately? Are there proper fallbacks?
- **Input Validation**: Is user input validated? Are boundary conditions checked?
- **Backward Compatibility**: Do the changes break existing functionality?

#### Maintainability
- **Code Structure**: Is the changed code well-organized? Are functions/methods appropriately sized?
- **Comments**: Are complex sections explained? Are comments up-to-date and helpful?
- **Magic Numbers**: Are hardcoded values extracted into named constants?
- **Dependencies**: Are new dependencies necessary and well-managed?

#### Performance
- **Efficiency**: Are there obvious performance issues in the changes? Unnecessary loops, inefficient algorithms?
- **Resource Usage**: Is memory managed properly? Are resources (files, connections) closed?
- **Scaling**: Will the changes perform well as data grows?

#### Security
- **Input Sanitization**: Is user input properly sanitized to prevent injection attacks?
- **Authentication/Authorization**: Are access controls properly implemented?
- **Sensitive Data**: Are secrets, passwords, or API keys hardcoded?
- **Dependencies**: Do new dependencies have known vulnerabilities?

#### Testing
- **Test Coverage**: Are there tests for the new/changed code?
- **Test Quality**: Are tests meaningful and maintainable?
- **Edge Cases**: Are boundary conditions and error cases tested?
- **Existing Tests**: Do existing tests still pass?

### 3. Provide Feedback

For each issue identified in the changes, provide:

**Location**: `path/to/file.ts:123`

**Issue Description**: Clear explanation of what the problem is

**Impact**: Why this matters (readability, bugs, security, performance, etc.)

**Suggestion**: Specific recommendation for improvement, including code examples when helpful

**Severity**: 
- **Critical** - Security issues, major bugs, data loss risks
- **High** - Significant quality issues, likely bugs, poor maintainability
- **Medium** - Code smells, minor issues, improvement opportunities
- **Low** - Nitpicks, style preferences, optional enhancements

### 4. Positive Feedback

Also highlight what's done well in the changes:
- Good design decisions
- Clear and readable code
- Proper error handling
- Well-structured tests
- Good documentation

### 5. Summary

End with a summary that includes:
- **Changes Overview**: Brief description of what was changed
- **Overall Assessment**: General quality of the changes
- **Key Strengths**: What's working well
- **Priority Issues**: Top 3-5 things to address first
- **Optional Improvements**: Nice-to-haves for future consideration

## After the Review

Once you've completed the code review and provided feedback:

1. **Ask if they'd like help fixing issues**: Offer to help implement the suggested improvements
2. **Prioritize fixes**: If multiple issues were found, help prioritize which to address first
3. **Implement fixes**: If requested, work through fixing the identified issues systematically
4. **Re-review if needed**: After fixes are applied, offer to do a quick re-review to confirm issues are resolved

## Example Review Format

```markdown
## Code Review Summary

### Changes Overview
Added new user authentication endpoint and updated login flow to support OAuth providers.

### Overall Assessment
The implementation is solid with good test coverage. There are a few security concerns that should be addressed before merging.

### Positive Observations
- Comprehensive test coverage for new authentication flows
- Good use of TypeScript types for type safety
- Clear separation of concerns between auth logic and API handlers

### Issues Found

#### [CRITICAL] Hardcoded Secret Key
**Location:** `src/auth/oauth.ts:23`
**Description:** OAuth client secret is hardcoded in the source code
**Impact:** Security vulnerability - secrets should never be committed to version control
**Suggestion:** Move to environment variables:
\`\`\`typescript
const clientSecret = process.env.OAUTH_CLIENT_SECRET;
if (!clientSecret) {
  throw new Error('OAUTH_CLIENT_SECRET environment variable is required');
}
\`\`\`

#### [HIGH] Missing Error Handling
**Location:** `src/api/auth.ts:45`
**Description:** The OAuth callback doesn't handle provider errors
**Impact:** Could cause unhandled promise rejections if OAuth provider returns an error
**Suggestion:** Add try-catch block and proper error handling

#### [MEDIUM] Code Duplication
**Location:** `src/utils/token.ts:12` and `src/utils/token.ts:34`
**Description:** JWT validation logic is duplicated
**Impact:** Harder to maintain, risk of inconsistency
**Suggestion:** Extract common validation logic into a shared helper function

### Priority Recommendations
1. Remove hardcoded secret and use environment variable (CRITICAL)
2. Add error handling for OAuth provider failures (HIGH)
3. Extract duplicated JWT validation logic (MEDIUM)

Would you like me to help implement these improvements?
```

## Tips for Effective Reviews

- **Focus on the diff**: Only review what changed, not the entire codebase
- **Be constructive**: Focus on improvement, not criticism
- **Explain the "why"**: Help the developer understand the reasoning behind suggestions
- **Provide examples**: Show concrete code examples when suggesting changes
- **Be specific**: Reference exact lines and files
- **Balance feedback**: Point out good things along with issues
- **Consider context**: Not every issue needs to be fixed immediately
- **Be practical**: Suggest improvements that are actually achievable
- **Respect intent**: Try to understand what the developer was trying to achieve
