Ensure the code follows security best practices by adhering to the following rules categorized by severity and topic.

## Critical Security Rules

### 1. Injection Prevention (CRITICAL)

**Rule**: All user input MUST be validated and sanitized. SQL queries MUST use parameterized queries or prepared statements. NEVER concatenate user input into queries or commands.

**Check for**:

- SQL injection vulnerabilities in database queries
- OS command injection in system calls
- LDAP injection in directory queries
- NoSQL injection in database operations
- XML/XXE injection in XML parsers

**References**:

- [SQL Injection Prevention](./codeguard-0-sql-injection-prevention.md)
- [OS Command Injection Defense](./codeguard-0-os-command-injection-defense.md)
- [LDAP Injection Prevention](./codeguard-0-ldap-injection-prevention.md)
- [Query Parameterization](./codeguard-0-query-parameterization.md)
- [XML External Entity Prevention](./codeguard-0-xml-external-entity-prevention.md)

### 2. Cross-Site Scripting (XSS) Prevention (CRITICAL)

**Rule**: All user-supplied data rendered in HTML MUST be properly encoded based on context (HTML entity, JavaScript, URL, CSS). Use context-aware output encoding. Implement Content Security Policy.

**Check for**:

- Unescaped user input in HTML templates
- Direct DOM manipulation with user data
- Missing CSP headers
- Unsafe use of innerHTML, eval(), or similar dangerous functions
- DOM clobbering vulnerabilities

**References**:

- [Cross-Site Scripting Prevention](./codeguard-0-cross-site-scripting-prevention.md)
- [DOM-based XSS Prevention](./codeguard-0-dom-based-xss-prevention.md)
- [DOM Clobbering Prevention](./codeguard-0-dom-clobbering-prevention.md)
- [Content Security Policy](./codeguard-0-content-security-policy.md)

### 3. Authentication & Session Management (CRITICAL)

**Rule**: Passwords MUST be hashed using Argon2, bcrypt, or PBKDF2 (NEVER plain text or weak hashes like MD5/SHA1). Sessions MUST have timeout, rotation, and secure cookies (HttpOnly, Secure, SameSite). Multi-factor authentication SHOULD be implemented for sensitive operations.

**Check for**:

- Weak password hashing algorithms
- Missing HttpOnly or Secure flags on session cookies
- Lack of session timeout or rotation
- Missing MFA on sensitive operations
- Credential stuffing vulnerabilities
- Insecure password reset flows

**References**:

- [Authentication](./codeguard-0-authentication.md)
- [Password Storage](./codeguard-0-password-storage.md)
- [Session Management](./codeguard-0-session-management.md)
- [Multifactor Authentication](./codeguard-0-multifactor-authentication.md)
- [Credential Stuffing Prevention](./codeguard-0-credential-stuffing-prevention.md)
- [Forgot Password Security](./codeguard-0-forgot-password.md)

### 4. Authorization & Access Control (CRITICAL)

**Rule**: Implement deny-by-default authorization. EVERY resource access MUST have explicit authorization checks. Prevent Insecure Direct Object References (IDOR) by validating user permissions before data access.

**Check for**:

- Missing authorization checks on endpoints/functions
- IDOR vulnerabilities (accessing other users' data)
- Privilege escalation paths
- Mass assignment vulnerabilities
- Missing role/permission validation

**References**:

- [Authorization](./codeguard-0-authorization.md)
- [Insecure Direct Object Reference Prevention](./codeguard-0-insecure-direct-object-reference-prevention.md)
- [Mass Assignment Prevention](./codeguard-0-mass-assignment.md)
- [Authorization Testing Automation](./codeguard-0-authorization-testing-automation.md)

### 5. Cross-Site Request Forgery (CSRF) Prevention (HIGH)

**Rule**: All state-changing operations MUST be protected with CSRF tokens or use SameSite cookies. API endpoints MUST validate Origin/Referer headers for non-GET requests.

**Check for**:

- Missing CSRF protection on POST/PUT/DELETE endpoints
- Missing SameSite cookie attribute
- Lack of token validation in forms
- GET requests that modify state

**References**:

- [CSRF Prevention](./codeguard-0-cross-site-request-forgery-prevention.md)
- [Cookie Theft Mitigation](./codeguard-0-cookie-theft-mitigation.md)

## High Priority Security Rules

### 6. Cryptographic Security (HIGH)

**Rule**: Use industry-standard, up-to-date cryptographic libraries. NEVER implement custom cryptography. Use TLS 1.2+ for all data in transit. Use AES-256-GCM or ChaCha20-Poly1305 for encryption at rest.

**Check for**:

- Weak encryption algorithms (DES, RC4, MD5, SHA1)
- Hardcoded secrets/keys in code
- Missing TLS or weak TLS configuration
- Insecure random number generation
- Improper key management

**References**:

- [Cryptographic Storage](./codeguard-0-cryptographic-storage.md)
- [Key Management](./codeguard-0-key-management.md)
- [Transport Layer Security](./codeguard-0-transport-layer-security.md)
- [HTTP Strict Transport Security](./codeguard-0-http-strict-transport-security.md)

### 7. Input Validation (HIGH)

**Rule**: Validate ALL input on the server side using allowlists. Reject invalid input rather than trying to sanitize. Validate data type, length, format, and range.

**Check for**:

- Missing input validation
- Blacklist-based validation (use allowlists instead)
- Client-side only validation
- Lack of length limits
- Missing type checking

**References**:

- [Input Validation](./codeguard-0-input-validation.md)
- [Bean Validation](./codeguard-0-bean-validation.md)

### 8. Deserialization Security (HIGH)

**Rule**: NEVER deserialize untrusted data without validation. Use safe serialization formats (JSON) instead of language-specific formats when possible. Validate object types before deserialization.

**Check for**:

- Unsafe deserialization of user input
- Use of pickle, serialize, or ObjectInputStream on untrusted data
- Missing type validation before deserialization
- Prototype pollution in JavaScript

**References**:

- [Deserialization Security](./codeguard-0-deserialization.md)
- [Prototype Pollution Prevention](./codeguard-0-prototype-pollution-prevention.md)

### 9. Error Handling & Information Disclosure (HIGH)

**Rule**: Error messages MUST NOT expose sensitive information (stack traces, database details, file paths, internal system info). Log errors server-side but show generic messages to users.

**Check for**:

- Stack traces exposed to users
- Detailed error messages revealing system internals
- Database connection strings in errors
- Missing error handling (causing crashes)

**References**:

- [Error Handling](./codeguard-0-error-handling.md)
- [Logging Vocabulary](./codeguard-0-logging-vocabulary.md)

### 10. File Upload Security (HIGH)

**Rule**: Validate file types by content (magic bytes), not just extension. Store uploaded files outside web root. Scan files for malware. Limit file sizes.

**Check for**:

- Missing file type validation
- Files stored in web-accessible directories
- Lack of file size limits
- Missing malware scanning
- Path traversal in file names

**References**:

- [File Upload Security](./codeguard-0-file-upload.md)

## API & Web Service Security Rules

### 11. REST API Security (MEDIUM)

**Rule**: APIs MUST use authentication (JWT, OAuth2) and authorization on all endpoints. Implement rate limiting. Validate content types. Use HTTPS only.

**Check for**:

- Unauthenticated API endpoints
- Missing rate limiting
- Lack of input validation
- Excessive data exposure
- Missing CORS configuration

**References**:

- [REST Security](./codeguard-0-rest-security.md)
- [REST Assessment](./codeguard-0-rest-assessment.md)
- [OAuth2 Security](./codeguard-0-oauth2.md)

### 12. GraphQL Security (MEDIUM)

**Rule**: Implement query depth limiting, query complexity analysis, and query cost analysis. Require authentication and implement field-level authorization.

**Check for**:

- Missing query depth limits (DoS risk)
- Lack of query complexity analysis
- Missing authorization on resolver fields
- Information disclosure through introspection

**References**:

- [GraphQL Security](./codeguard-0-graphql.md)

### 13. Server-Side Request Forgery (SSRF) Prevention (MEDIUM)

**Rule**: Validate and sanitize all URLs used in server-side requests. Use allowlists for allowed domains. Disable redirects or validate redirect targets.

**Check for**:

- User-controlled URLs in server requests
- Missing URL validation
- Access to internal network resources
- Cloud metadata endpoint access

**References**:

- [SSRF Prevention](./codeguard-0-server-side-request-forgery-prevention.md)

## Security Headers & Browser Protection

### 14. Security Headers (MEDIUM)

**Rule**: Implement essential security headers: Content-Security-Policy, X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security, Referrer-Policy.

**Check for**:

- Missing CSP header
- Missing X-Frame-Options (clickjacking risk)
- Missing HSTS header
- Permissive CORS policies
- Missing X-Content-Type-Options

**References**:

- [HTTP Security Headers](./codeguard-0-http-headers.md)
- [Clickjacking Defense](./codeguard-0-clickjacking-defense.md)
- [AJAX Security](./codeguard-0-ajax-security.md)

### 15. Redirect & Forward Validation (MEDIUM)

**Rule**: Validate all redirects and forwards against an allowlist. NEVER redirect to user-supplied URLs without validation.

**Check for**:

- Unvalidated redirect parameters
- Open redirect vulnerabilities
- User-controlled forward destinations

**References**:

- [Unvalidated Redirects and Forwards](./codeguard-0-unvalidated-redirects-and-forwards.md)
- [Open Redirect Prevention](./codeguard-0-open-redirect.md)

## Infrastructure & DevOps Security

### 16. Container & Orchestration Security (MEDIUM)

**Rule**: Run containers as non-root users. Drop unnecessary capabilities. Use minimal base images. Scan images for vulnerabilities. Implement pod security policies.

**Check for**:

- Containers running as root
- Excessive container capabilities
- Missing security contexts
- Vulnerable base images
- Secrets in container images

**References**:

- [Docker Security](./codeguard-0-docker-security.md)
- [Kubernetes Security](./codeguard-0-kubernetes-security.md)
- [Node.js Docker](./codeguard-0-nodejs-docker.md)

### 17. CI/CD Pipeline Security (MEDIUM)

**Rule**: Secure CI/CD pipelines with least privilege access. Store secrets in secure vaults, not in code or environment variables. Sign artifacts. Implement supply chain security.

**Check for**:

- Secrets in CI/CD configuration
- Missing artifact verification
- Overly permissive pipeline permissions
- Lack of SBOM generation

**References**:

- [CI/CD Security](./codeguard-0-ci-cd-security.md)
- [Vulnerable Dependency Management](./codeguard-0-vulnerable-dependency-management.md)
- [NPM Security](./codeguard-0-npm-security.md)

## Language-Specific Security Rules

### 18. JavaScript/Node.js Security (varies by issue)

**Rule**: Avoid eval(), Function(), setTimeout/setInterval with strings. Validate all input. Use strict mode. Implement CSP. Avoid prototype pollution.

**Check for**:

- Use of eval() or Function()
- Prototype pollution vulnerabilities
- Missing input validation
- Vulnerable dependencies
- Insecure randomness (Math.random())

**References**:

- [Node.js Security](./codeguard-0-nodejs-security.md)
- [Prototype Pollution Prevention](./codeguard-0-prototype-pollution-prevention.md)
- [NPM Security](./codeguard-0-npm-security.md)

### 19. Java Security (varies by issue)

**Rule**: Use PreparedStatement for SQL queries. Implement input validation with Bean Validation. Avoid reflection with untrusted input. Use secure random (SecureRandom).

**References**:

- [Java Security](./codeguard-0-java-security.md)
- [Bean Validation](./codeguard-0-bean-validation.md)
- [JSON Web Token for Java](./codeguard-0-json-web-token-for-java.md)
- [JAAS Security](./codeguard-0-jaas.md)

### 20. Python/Django Security (varies by issue)

**Rule**: Use Django's ORM or parameterized queries. Enable middleware (CSRF, Clickjacking, Security). Use safe template rendering. Validate serializer input.

**References**:

- [Django Security](./codeguard-0-django-security.md)
- [Django REST Framework](./codeguard-0-django-rest-framework.md)

### 21. PHP Security (varies by issue)

**Rule**: Disable dangerous functions (eval, exec, system). Use prepared statements. Set proper php.ini configurations. Validate all input.

**References**:

- [PHP Configuration](./codeguard-0-php-configuration.md)

### 22. Ruby/Rails Security (varies by issue)

**Rule**: Use parameterized queries. Enable CSRF protection. Sanitize HTML output. Use strong_parameters.

**References**:

- [Ruby on Rails Security](./codeguard-0-ruby-on-rails.md)

### 23. .NET Security (varies by issue)

**Rule**: Use parameterized queries. Enable anti-forgery tokens. Implement proper authorization. Validate all input.

**References**:

- [DotNet Security](./codeguard-0-dotnet-security.md)

### 24. C/C++ Security (varies by issue)

**Rule**: Use memory-safe functions. Avoid buffer overflows. Enable compiler hardening flags (ASLR, DEP, stack canaries). Validate all input lengths.

**References**:

- [Safe C Functions](./codeguard-0-safe-c-functions.md)
- [C-Based Toolchain Hardening](./codeguard-0-c-based-toolchain-hardening.md)
- [Memory/String Usage Guidelines](./codeguard-0-cw-memory-string-usage-guidelines.md)

## Mobile Security Rules

### 25. Mobile Application Security (varies by issue)

**Rule**: Encrypt sensitive data at rest. Use certificate pinning. Implement secure storage (Keychain/Keystore). Validate all server responses. Enable code obfuscation.

**References**:

- [Mobile Application Security](./codeguard-0-mobile-application-security.md)
- [Pinning](./codeguard-0-pinning.md)

## Review Priority Guide

When reviewing code, prioritize issues in this order:

1. **CRITICAL**: SQL Injection, XSS, Authentication Bypass, Authorization Bypass, RCE
2. **HIGH**: Weak Cryptography, Insecure Deserialization, CSRF, Information Disclosure, File Upload Issues
3. **MEDIUM**: Missing Security Headers, SSRF, Open Redirects, API Security Issues, Container Security
4. **LOW**: Configuration hardening, logging improvements, dependency updates

## Quick Security Checklist

For every code change, verify:

- [ ] All user input is validated
- [ ] SQL queries use parameterized/prepared statements
- [ ] Output is properly encoded for context (HTML, JS, URL, CSS)
- [ ] Authentication is required where needed
- [ ] Authorization checks are present and deny-by-default
- [ ] CSRF protection is enabled for state-changing operations
- [ ] Secrets are not hardcoded
- [ ] Error messages don't leak sensitive information
- [ ] Security headers are configured
- [ ] HTTPS is enforced
- [ ] Dependencies are up-to-date and scanned for vulnerabilities

## Additional Resources

- [Attack Surface Analysis](./codeguard-0-attack-surface-analysis.md) - Identify entry points
- [Threat Modeling](./codeguard-0-threat-modeling.md) - Systematic threat identification
- [Zero Trust Architecture](./codeguard-0-zero-trust-architecture.md) - Zero trust principles
- [Microservices Security](./codeguard-0-microservices-security.md) - Service-to-service security
- [User Privacy Protection](./codeguard-0-user-privacy-protection.md) - Privacy considerations
