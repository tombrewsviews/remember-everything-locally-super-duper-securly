# Future Development Roadmap

## Priority 1: Security Hardening

### At-Rest Encryption
- Encrypt `~/.systemname/files/` using macOS FileVault or application-level encryption
- Consider age/GPG encryption for individual notes

### Access Code Improvements
- Variable-length codes (minimum 8 characters recommended)
- Optional TOTP/time-based one-time passwords
- Rate limiting after failed attempts (exponential backoff)
- Current code verification before allowing changes
- Secure memory handling (clear code from memory after hashing)

### TLS for Remote Mode
- Auto-generate self-signed certificates for `--remote` mode
- Or integrate Let's Encrypt via Tailscale HTTPS certs

### Process Stealth
- Rename Khoj process to a generic name
- Clear command from shell history after launch

## Priority 2: Reliability

### Installer Robustness
- Add rollback mechanism for partial installation failures
- Idempotent re-run support (detect existing install and upgrade)
- Health check after install completes
- Version tracking for upgrades

### Watcher Improvements
- File deduplication (content hash comparison)
- Configurable file size limits
- Support for nested subdirectories in inbox
- Log rotation (prevent unbounded growth)
- Health check endpoint or monitoring
- Retry mechanism for failed imports

### Backup & Restore
- Automated backup script (database + files + config)
- Restore script from backup archive
- Scheduled backups via LaunchAgent

### Error Handling
- Graceful shutdown handler for Khoj process (SIGTERM/SIGINT)
- PID file for process management
- Startup health verification (PostgreSQL connection, port availability)
- User-facing error log with human-readable messages

## Priority 3: Features

### Multi-Format Support
- Image import with OCR (Tesseract or macOS Vision framework)
- Audio file import with transcription (Whisper)
- PDF import with text extraction
- URL bookmarking with content snapshot

### Enhanced Mobile
- Progressive Web App (PWA) wrapper for Khoj
- Native iOS Shortcut for quick note capture with better UI
- iCloud Drive support as Google Drive alternative
- Push notifications for successful imports

### Search & Organization
- Tags and categories for notes
- Automatic daily/weekly digest generation
- Smart folders based on content classification
- Timeline view of notes

### Multi-Device Sync
- Encrypted sync between multiple Macs
- Conflict resolution strategy
- Selective sync (choose which notes to sync)

## Priority 4: Developer Experience

### Testing
- Shell script test suite (using bats or shunit2)
- Integration tests for installer (Docker-based macOS simulation)
- End-to-end test for the import pipeline

### CI/CD
- GitHub Actions for linting shell scripts (shellcheck)
- Automated release packaging
- Version bumping and changelog generation

### Documentation
- Man page for the launch command
- Troubleshooting guide
- Architecture decision records (ADRs)
- Contributing guide

## Non-Goals
- Windows or Linux support (macOS-only by design)
- Multi-user support (single-user system)
- Cloud hosting (local-only by design)
- Web-based admin (Khoj provides this already)
- Plugin system (rely on Khoj's extension points)
