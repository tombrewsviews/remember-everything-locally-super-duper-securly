# Core Security Rules
This documentation tile contains comprehensive security rules that AI agents should follow when writing, reviewing, or analyzing code. These rules cover authentication, authorization, cryptography, input validation, secure coding practices, and infrastructure security across multiple languages and frameworks. These are rules and conventions which our used across our codebases.

## Security Rules Index

### Authentication & Authorization
- [Authentication & MFA](./codeguard-0-authentication-mfa.md) - Authentication and MFA best practices including passwords, OAuth/OIDC, SAML, and recovery
- [Authorization & Access Control](./codeguard-0-authorization-access-control.md) - Authorization patterns including RBAC/ABAC/ReBAC, IDOR prevention, and transaction authorization
- [Session Management & Cookies](./codeguard-0-session-management-and-cookies.md) - Session management best practices including rotation, fixation prevention, and theft detection

### Web Security
- [API & Web Services Security](./codeguard-0-api-web-services.md) - Security for REST/GraphQL/SOAP APIs including schema validation, authn/z, and SSRF prevention
- [Client-side Web Security](./codeguard-0-client-side-web-security.md) - XSS/DOM XSS prevention, CSP, CSRF, clickjacking, XS-Leaks, and third-party JavaScript safety
- [Input Validation & Injection Defense](./codeguard-0-input-validation-injection.md) - Input validation and defense against SQL/LDAP/OS injection and prototype pollution

### Cryptography & Data Protection
- [Additional Cryptography](./codeguard-0-additional-cryptography.md) - Cryptography and TLS configuration including algorithms, key management, and HSTS
- [Cryptographic Algorithms](./codeguard-1-crypto-algorithms.md) - Guidelines for secure cryptographic algorithm selection and usage
- [Digital Certificates](./codeguard-1-digital-certificates.md) - Certificate validation, expiration checks, and PKI best practices
- [Privacy & Data Protection](./codeguard-0-privacy-data-protection.md) - Privacy controls including minimization, classification, encryption, and user rights
- [Data Storage Security](./codeguard-0-data-storage.md) - Database security including isolation, TLS, least privilege, RLS/CLS, and backups

### Infrastructure & DevOps
- [Infrastructure as Code Security](./codeguard-0-iac-security.md) - IaC security for Terraform, CloudFormation, and cloud infrastructure
- [Cloud & Orchestration (Kubernetes)](./codeguard-0-cloud-orchestration-kubernetes.md) - Kubernetes hardening including RBAC, admission policies, network policies, and secrets
- [DevOps, CI/CD, and Containers](./codeguard-0-devops-ci-cd-containers.md) - Pipeline hardening, artifact security, Docker/K8s image security, and virtual patching
- [Dependency & Supply Chain Security](./codeguard-0-supply-chain-security.md) - Dependency management including pinning, SBOM, provenance, and integrity verification

### Language & Framework Specific
- [Framework & Language Guides](./codeguard-0-framework-and-languages.md) - Security guides for Django/DRF, Laravel/Symfony/Rails, .NET, Java/JAAS, Node.js, and PHP
- [Safe C Functions](./codeguard-0-safe-c-functions.md) - Memory and string safety guidelines for C/C++ including safe function alternatives
- [Mobile Applications](./codeguard-0-mobile-apps.md) - iOS/Android security including storage, transport, code integrity, biometrics, and permissions

### Data Handling
- [File Handling & Uploads](./codeguard-0-file-handling-and-uploads.md) - Secure file handling including validation, storage isolation, scanning, and safe delivery
- [XML & Serialization Hardening](./codeguard-0-xml-and-serialization.md) - XML security and safe deserialization including DTD/XXE hardening and schema validation

### Observability & Secrets
- [Logging & Monitoring](./codeguard-0-logging.md) - Structured logging, telemetry, redaction, integrity, and detection alerting
- [No Hardcoded Credentials](./codeguard-1-hardcoded-credentials.md) - Prevention of hardcoded secrets, passwords, and API keys in source code
