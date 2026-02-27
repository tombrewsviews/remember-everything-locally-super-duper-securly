# Security Review Tile

A Claude Code skill for conducting comprehensive security reviews of codebases.

## Usage

Invoke the skill with:
```
/tessl-security-review
```

Or ask Claude Code naturally:
- "Review this codebase for security issues"
- "What vulnerabilities exist in this project?"
- "Conduct a security audit"

## What It Does

The skill performs a three-phase security review:

1. **Reconnaissance** - Analyzes the tech stack, frameworks, and attack surface
2. **Parallel Analysis** - Spawns 7 specialized sub-agents to check for:
   - Hardcoded secrets and credentials
   - Injection vulnerabilities (SQL, command, path traversal)
   - Authentication and authorization flaws
   - Input validation and XSS issues
   - Cryptographic weaknesses
   - Dependency vulnerabilities
   - Error handling and logging issues
3. **Consolidated Report** - Produces a severity-ranked report with remediation guidance

## Output

Findings are categorized by severity:
- **CRITICAL** - Immediate exploitation risk
- **HIGH** - Significant vulnerabilities
- **MEDIUM** - Security weaknesses to address
- **LOW** - Hardening recommendations

Each finding includes location, description, impact, and remediation steps.
