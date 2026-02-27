---
name: software-security
description: A software security skill that integrates with Project CodeGuard to help AI coding agents write secure code and prevent common vulnerabilities. Use this skill when security concerns are mentioned, when reviewing code for vulnerabilities, or when implementing authentication, cryptography, or data handling.
license: Apache-2.0
metadata:
  version: "1.2.0"
  framework: "Project CodeGuard"
---

# Software Security Skill

## When to Use This Skill

Activate when:
- Writing new code in any language
- Reviewing or modifying existing code
- Implementing security-sensitive features (authentication, cryptography, data handling)
- Working with user input, databases, APIs, or external services
- Configuring cloud infrastructure, CI/CD pipelines, or containers
- Handling sensitive data, credentials, or cryptographic operations

## Always-Apply Rules

These rules MUST be checked on every code operation:

- [codeguard-1-hardcoded-credentials](rules/codeguard-1-hardcoded-credentials.md) - Never hardcode secrets, passwords, API keys, or tokens
- [codeguard-1-crypto-algorithms](rules/codeguard-1-crypto-algorithms.md) - Use only modern, secure cryptographic algorithms
- [codeguard-1-digital-certificates](rules/codeguard-1-digital-certificates.md) - Validate and manage digital certificates securely

## Context-Specific Rules

Apply rules from [LANGUAGE_RULES.md](LANGUAGE_RULES.md) based on the language being used.

## Security Examples

### Credential Handling

```python
# INSECURE - hardcoded credentials
db_password = "secret123"
api_key = "sk-1234567890"

# SECURE - use environment variables
import os
db_password = os.environ["DB_PASSWORD"]
api_key = os.environ["API_KEY"]
```

### SQL Queries

```python
# INSECURE - string concatenation (SQL injection risk)
query = f"SELECT * FROM users WHERE id = {user_id}"

# SECURE - parameterized queries
query = "SELECT * FROM users WHERE id = %s"
cursor.execute(query, (user_id,))
```

### Password Storage

```python
# INSECURE - plain text or weak hashing
stored_password = password  # plain text
stored_password = hashlib.md5(password).hexdigest()  # weak hash

# SECURE - use bcrypt or argon2
import bcrypt
stored_password = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
```

## Workflow

### 1. Initial Security Check

Before writing any code:
- Check: Will this handle credentials? → Apply [codeguard-1-hardcoded-credentials](rules/codeguard-1-hardcoded-credentials.md)
- Check: What language am I using? → Identify applicable rules from [LANGUAGE_RULES.md](LANGUAGE_RULES.md)
- Check: What security domains are involved? → Load relevant rule files

### 2. Code Generation

While writing code:
- Apply secure-by-default patterns from relevant rules
- Add security-relevant comments explaining choices

### 3. Security Review

After writing code:
- Review against implementation checklists in each rule
- Verify no hardcoded credentials or secrets
- Validate that all applicable rules have been followed
- Explain which security rules were applied
