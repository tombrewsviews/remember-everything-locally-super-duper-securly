# OWASP Security Rules

This documentation tile contains security rules based on the OWASP (Open Web Application Security Project) Cheat Sheet Series. These comprehensive rules cover web application security, API security, authentication, authorization, cryptography, and secure coding practices across multiple programming languages and frameworks. These are rules and conventions which our used across our codebases.

## Security Rules Index

### Web Security
- [AJAX Security](./codeguard-0-ajax-security.md) - Security best practices for client-side AJAX scripts and dynamic JavaScript
- [Client-Side XSS Prevention](./codeguard-0-cross-site-scripting-prevention.md) - Comprehensive XSS prevention with context-aware output encoding
- [DOM-based XSS Prevention](./codeguard-0-dom-based-xss-prevention.md) - Prevention of DOM XSS through secure DOM manipulation and Trusted Types
- [DOM Clobbering Prevention](./codeguard-0-dom-clobbering-prevention.md) - Protection against DOM clobbering attacks with proper sanitization
- [XSS Filter Evasion](./codeguard-0-xss-filter-evasion.md) - Understanding and preventing XSS filter bypass techniques
- [CSRF Prevention](./codeguard-0-cross-site-request-forgery-prevention.md) - Cross-Site Request Forgery prevention with synchronizer tokens and SameSite cookies
- [Clickjacking Defense](./codeguard-0-clickjacking-defense.md) - Protection against UI redress attacks using frame-ancestors and X-Frame-Options
- [Content Security Policy](./codeguard-0-content-security-policy.md) - CSP implementation for defense-in-depth against injection attacks
- [XS-Leaks](./codeguard-0-xs-leaks.md) - Cross-site leak prevention and mitigation strategies
- [Unvalidated Redirects and Forwards](./codeguard-0-unvalidated-redirects-and-forwards.md) - Prevention of open redirect vulnerabilities

### API & Web Services
- [REST Security](./codeguard-0-rest-security.md) - Security best practices for RESTful API development
- [REST Assessment](./codeguard-0-rest-assessment.md) - Security assessment guidelines for REST APIs
- [GraphQL Security](./codeguard-0-graphql.md) - GraphQL-specific security including query limiting and authorization
- [Web Service Security](./codeguard-0-web-service-security.md) - SOAP and web services security practices
- [Server-Side Request Forgery Prevention](./codeguard-0-server-side-request-forgery-prevention.md) - SSRF prevention for outbound requests

### Authentication & Authorization
- [Authentication](./codeguard-0-authentication.md) - Authentication security including passwords, MFA, and OAuth/OIDC
- [Multifactor Authentication](./codeguard-0-multifactor-authentication.md) - MFA implementation with phishing-resistant factors
- [Authorization](./codeguard-0-authorization.md) - Authorization patterns including RBAC/ABAC/ReBAC and deny-by-default
- [Authorization Testing Automation](./codeguard-0-authorization-testing-automation.md) - Automated testing using authorization matrices
- [Session Management](./codeguard-0-session-management.md) - Secure session handling, rotation, and theft detection
- [Cookie Theft Mitigation](./codeguard-0-cookie-theft-mitigation.md) - Session fingerprinting and cookie theft detection
- [Credential Stuffing Prevention](./codeguard-0-credential-stuffing-prevention.md) - Defense against credential stuffing and password spraying
- [Forgot Password Security](./codeguard-0-forgot-password.md) - Secure password reset implementation
- [OAuth2 Security](./codeguard-0-oauth2.md) - OAuth 2.0 and OpenID Connect security best practices
- [SAML Security](./codeguard-0-saml-security.md) - SAML implementation and XML signature validation
- [JAAS Security](./codeguard-0-jaas.md) - Java Authentication and Authorization Service (JAAS) patterns
- [Choosing Security Questions](./codeguard-0-choosing-and-using-security-questions.md) - Implementation guidelines for security questions (legacy systems)
- [Transaction Authorization](./codeguard-0-transaction-authorization.md) - Step-up authentication for sensitive operations

### Injection Prevention
- [Injection Prevention](./codeguard-0-injection-prevention.md) - General injection defense including SQL, LDAP, and OS command injection
- [SQL Injection Prevention](./codeguard-0-sql-injection-prevention.md) - Prepared statements and parameterized queries
- [LDAP Injection Prevention](./codeguard-0-ldap-injection-prevention.md) - DN and search filter escaping for LDAP
- [OS Command Injection Defense](./codeguard-0-os-command-injection-defense.md) - Prevention of command injection through parameterization
- [Query Parameterization](./codeguard-0-query-parameterization.md) - Safe database query construction
- [Prototype Pollution Prevention](./codeguard-0-prototype-pollution-prevention.md) - JavaScript prototype pollution mitigation
- [XML External Entity Prevention](./codeguard-0-xml-external-entity-prevention.md) - XXE prevention with DTD disabling
- [XML Security](./codeguard-0-xml-security.md) - Comprehensive XML parsing and processing security

### Input Validation & Data Handling
- [Input Validation](./codeguard-0-input-validation.md) - Allowlist validation and syntactic/semantic checking
- [Bean Validation](./codeguard-0-bean-validation.md) - Java Bean Validation for declarative input validation
- [Deserialization Security](./codeguard-0-deserialization.md) - Safe deserialization practices to prevent RCE
- [Mass Assignment Prevention](./codeguard-0-mass-assignment.md) - Protection against mass assignment with DTOs
- [Insecure Direct Object Reference Prevention](./codeguard-0-insecure-direct-object-reference-prevention.md) - IDOR prevention through access control checks
- [File Upload Security](./codeguard-0-file-upload.md) - Secure file upload with validation, storage, and scanning

### Cryptography & Data Protection
- [Cryptographic Storage](./codeguard-0-cryptographic-storage.md) - Data-at-rest encryption and key management
- [Key Management](./codeguard-0-key-management.md) - Cryptographic key lifecycle and secure storage
- [Password Storage](./codeguard-0-password-storage.md) - Password hashing with Argon2, bcrypt, and PBKDF2
- [Transport Layer Security](./codeguard-0-transport-layer-security.md) - TLS configuration and cipher suite selection
- [HTTP Strict Transport Security](./codeguard-0-http-strict-transport-security.md) - HSTS implementation and phased rollout
- [Pinning](./codeguard-0-pinning.md) - Certificate and public key pinning for mobile apps
- [Cryptographic Guidelines (CW)](./codeguard-0-cw-cryptographic-security-guidelines.md) - Deprecated APIs and algorithm guidance
- [Digital Certificate Security](./codeguard-0-pinning.md) - Certificate validation and PKI best practices

### Infrastructure & DevOps
- [Docker Security](./codeguard-0-docker-security.md) - Container hardening including non-root users and capability dropping
- [Kubernetes Security](./codeguard-0-kubernetes-security.md) - K8s cluster and workload security with RBAC and pod security
- [CI/CD Security](./codeguard-0-ci-cd-security.md) - Pipeline hardening, secrets management, and artifact signing
- [Microservices Security](./codeguard-0-microservices-security.md) - Service-to-service authentication and distributed authorization
- [Network Segmentation](./codeguard-0-network-segmentation.md) - Network isolation and microsegmentation strategies
- [Virtual Patching](./codeguard-0-virtual-patching.md) - Temporary mitigation using WAF when code fixes aren't immediately available
- [Vulnerable Dependency Management](./codeguard-0-vulnerable-dependency-management.md) - SCA, SBOM, and dependency updates
- [NPM Security](./codeguard-0-npm-security.md) - Node.js package security and lockfile management
- [Legacy Application Management](./codeguard-0-legacy-application-management.md) - Security practices for maintaining legacy systems

### Language & Framework Specific
- [Django Security](./codeguard-0-django-security.md) - Django framework security including middleware and settings
- [Django REST Framework](./codeguard-0-django-rest-framework.md) - DRF-specific security with serializers and permissions
- [DotNet Security](./codeguard-0-dotnet-security.md) - ASP.NET Core security practices
- [Java Security](./codeguard-0-java-security.md) - Java secure coding including SQL injection and XSS prevention
- [JSON Web Token for Java](./codeguard-0-json-web-token-for-java.md) - JWT implementation and token sidejacking prevention
- [Laravel Security](./codeguard-0-laravel.md) - Laravel framework security patterns
- [Node.js Security](./codeguard-0-nodejs-security.md) - Node.js application security best practices
- [Node.js Docker](./codeguard-0-nodejs-docker.md) - Secure Node.js containerization
- [PHP Configuration](./codeguard-0-php-configuration.md) - PHP.ini hardening and runtime security
- [Ruby on Rails Security](./codeguard-0-ruby-on-rails.md) - Rails security patterns and dangerous functions
- [Symfony Security](./codeguard-0-symfony.md) - Symfony framework security practices
- [Safe C Functions](./codeguard-0-safe-c-functions.md) - Memory-safe C function replacements
- [C-Based Toolchain Hardening](./codeguard-0-c-based-toolchain-hardening.md) - Compiler and linker flags for C/C++ security
- [Memory/String Usage Guidelines (CW)](./codeguard-0-cw-memory-string-usage-guidelines.md) - Safe memory and string handling in C

### HTTP & Browser Security
- [HTTP Security Headers](./codeguard-0-http-headers.md) - Security headers including CSP, HSTS, and X-Frame-Options
- [HTML5 Security](./codeguard-0-html5-security.md) - postMessage, CORS, WebSocket, and Web Storage security
- [Securing CSS](./codeguard-0-securing-cascading-style-sheets.md) - CSS injection prevention and safe styling practices
- [Third-Party JavaScript Management](./codeguard-0-third-party-javascript-management.md) - Isolation and SRI for external scripts
- [Browser Extension Security](./codeguard-0-browser-extension-vulnerabilities.md) - Extension security including CSP and permissions
- [Open Redirect Prevention](./codeguard-0-open-redirect.md) - Validation of redirects and forwards

### Mobile Security
- [Mobile Application Security](./codeguard-0-mobile-application-security.md) - iOS/Android security including storage, transport, and integrity

### Database & Storage
- [Database Security](./codeguard-0-database-security.md) - Database isolation, encryption, and least privilege

### Logging & Monitoring
- [Error Handling](./codeguard-0-error-handling.md) - Secure error handling without information leakage
- [Logging Vocabulary](./codeguard-0-logging-vocabulary.md) - Standardized security event logging format
- [User Privacy Protection](./codeguard-0-user-privacy-protection.md) - Privacy-aware logging and data protection

### Security Architecture & Planning
- [Attack Surface Analysis](./codeguard-0-attack-surface-analysis.md) - Identifying and documenting entry points
- [Threat Modeling](./codeguard-0-threat-modeling.md) - Systematic threat identification and mitigation
- [Zero Trust Architecture](./codeguard-0-zero-trust-architecture.md) - Zero trust principles and implementation
