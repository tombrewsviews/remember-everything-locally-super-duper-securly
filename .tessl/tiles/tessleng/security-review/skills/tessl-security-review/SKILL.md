---
name: tessl-security-review
description: Conducts a comprehensive security review of a git repo. Use when asked about security issues, code quality concerns, or to evaluate the security posture of a codebase or library.
---

# Security Review Skill

Perform a comprehensive security review of the codebase. This skill uses parallel sub-agents to efficiently analyze different security domains simultaneously.

## Phase 1: Reconnaissance

Before spawning sub-agents, gather context about the codebase:

1. **Read project configuration** - Check `README.md`, `AGENTS.md`, `CLAUDE.md`, `package.json`, `Cargo.toml`, `go.mod`, or similar files to understand:

   - What language(s) and frameworks are used
   - What the application does
   - Any existing security guidance or constraints

2. **Identify the tech stack** - This determines which security checks are relevant:

   - Web frameworks (Express, Django, Rails, etc.) → focus on XSS, CSRF, injection
   - APIs → focus on auth, input validation, rate limiting
   - CLI tools → focus on argument injection, file path traversal
   - Libraries → focus on API safety, dependency security

3. **Map the attack surface** - Identify entry points:
   - HTTP routes and handlers
   - CLI argument parsing
   - File I/O operations
   - Database queries
   - External service integrations

## Phase 2: Parallel Security Analysis

Spawn sub-agents using the Task tool to analyze different security domains in parallel. Each agent should search for specific vulnerability patterns and report findings.

Launch these agents **in parallel** (all in a single message):

### Agent 1: Secrets and Credentials Scanner

```
Search the codebase for hardcoded secrets, API keys, credentials, and sensitive data exposure:
- Grep for patterns: API_KEY, SECRET, PASSWORD, TOKEN, PRIVATE_KEY, credentials
- Check .env files, config files, and test fixtures
- Look for base64-encoded secrets
- Check git history awareness (mentions of rotating secrets, etc.)
Report all findings with file:line references.
```

### Agent 2: Injection Vulnerabilities

```
Search for injection vulnerabilities:
- SQL injection: string concatenation in queries, raw SQL usage
- Command injection: shell exec, spawn, system calls with user input
- Path traversal: file operations with unsanitized paths
- Template injection: user input in template rendering
- NoSQL injection: MongoDB query construction with user input
Report all findings with file:line references and exploit scenarios.
```

### Agent 3: Authentication and Authorization

```
Review authentication and authorization implementation:
- Session management security
- Password handling (hashing, storage, transmission)
- JWT implementation (algorithm confusion, secret strength, expiration)
- Access control checks (missing authz on routes/functions)
- Privilege escalation vectors
Report all findings with file:line references.
```

### Agent 4: Input Validation and Output Encoding

```
Analyze input validation and output encoding:
- XSS vulnerabilities (unescaped user input in HTML/JS)
- Missing input validation on API endpoints
- Improper content-type handling
- File upload security (type validation, size limits, storage)
- Deserialization vulnerabilities
Report all findings with file:line references.
```

### Agent 5: Cryptography and Data Protection

```
Review cryptographic implementations and data protection:
- Weak algorithms (MD5, SHA1 for security purposes, DES, RC4)
- Insecure random number generation
- Improper key management
- Missing encryption for sensitive data at rest/transit
- Certificate validation issues
Report all findings with file:line references.
```

### Agent 6: Dependency and Supply Chain

```
Analyze dependencies for security issues:
- Check package.json, requirements.txt, Cargo.toml, go.mod for known vulnerable versions
- Look for abandoned or unmaintained dependencies
- Check for typosquatting risks in dependency names
- Review lockfile presence and integrity
- Check for dependency confusion risks
Report all findings with specific package names and versions.
```

### Agent 7: Error Handling and Logging

```
Review error handling and logging security:
- Sensitive data in error messages or stack traces
- Missing error handling that could lead to crashes
- Excessive logging of user data
- Log injection vulnerabilities
- Information disclosure through verbose errors
Report all findings with file:line references.
```

## Phase 3: Consolidate and Report

After all agents complete, consolidate their findings into a single report organized by severity:

### Severity Levels

| Level        | Description                                                              |
| ------------ | ------------------------------------------------------------------------ |
| **CRITICAL** | Actively exploitable, immediate risk of data breach or system compromise |
| **HIGH**     | Significant vulnerability, exploitation requires specific conditions     |
| **MEDIUM**   | Security weakness that should be addressed, limited exploitability       |
| **LOW**      | Minor issue or hardening recommendation                                  |

### Report Format

For each finding, include:

```markdown
### [SEVERITY] Title

**Location:** `path/to/file.ts:123`

**Description:** Clear explanation of the vulnerability.

**Impact:** What an attacker could achieve by exploiting this.

**Proof of Concept:** (if applicable)

- Steps to reproduce or exploit scenario

**Remediation:**

- Specific code changes or configuration updates needed
```

### Executive Summary

End the report with:

1. **Total findings by severity** - counts for each level
2. **Key risk areas** - the most concerning patterns found
3. **Priority recommendations** - top 3-5 actions to improve security posture
4. **Positive observations** - security practices done well (if any)

## Tool Usage Tips

When searching for vulnerabilities, use these Grep patterns:

```bash
# Secrets
Grep: (api[_-]?key|secret|password|token|credential|private[_-]?key)\s*[:=]

# SQL Injection
Grep: (query|execute|raw)\s*\(.*\+|`.*\$\{

# Command Injection
Grep: (exec|spawn|system|popen|shell)\s*\(

# Path Traversal
Grep: \.\./|\.\.\\

# Hardcoded IPs/URLs
Grep: (https?://|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)
```

## Important Notes

- Focus on **exploitable vulnerabilities** over theoretical risks
- Provide **actionable remediation** for every finding
- Include **file:line references** for all code issues
- Consider the **threat model** - what's the likely attacker profile?
- Acknowledge **security controls** that are working well
