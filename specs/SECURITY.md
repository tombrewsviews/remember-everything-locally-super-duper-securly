# Security Specification

## Threat Model
The system protects against casual discovery and unauthorized local access. It is NOT designed to resist:
- Forensic analysis by a skilled attacker with physical access
- Kernel-level rootkits or screen capture malware
- Compromised Homebrew supply chain

## Access Code System

**Source:** `scripts/setgrove.sh`, `scripts/logmem.sh`

### Setting the Code
1. User enters a 6-character code (hidden input via `read -s`)
2. Confirmation required (must match)
3. Code is hashed: `echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}'`
4. SHA-256 hash written to `~/.systemname/.sys/.grvmap` (chmod 600)

### Verifying the Code
1. Launch command presents blank prompt (no hint text)
2. User types code (not echoed)
3. Input is SHA-256 hashed and compared to stored hash
4. **Match:** server starts
5. **Mismatch:** `exit 0` — no error message, no distinction from success

### Security Properties
| Property | Implementation |
|----------|---------------|
| Code storage | SHA-256 hash only, never plaintext |
| Failed attempt visibility | None — silent exit 0 |
| Brute force protection | None (local-only mitigates this) |
| Code length | Fixed 6 characters |
| Character set | Unrestricted (any printable characters) |

### Weaknesses
- 6-character fixed length is discoverable via script inspection
- No rate limiting on attempts
- Hash stored in known location (`~/.systemname/.sys/.grvmap`)
- `shasum` invocation visible in process list during hashing
- Code transmitted over stdin — could be captured by keylogger

## File System Security

### Spotlight Exclusion
- `.metadata_never_index` placed in:
  - `~/.systemname/`
  - `~/.systemname/files/`
- Prevents macOS Spotlight from indexing note content

### Hidden Directory
- Dot-prefixed directory (`~/.systemname/`) — hidden from Finder by default
- `.gitignore` with `*` prevents accidental git tracking

### File Permissions
| File | Permissions | Content |
|------|------------|---------|
| `.grvmap` | 600 | SHA-256 access code hash |
| `khoj.env` | 600 | API keys, DB credentials, Django secret |
| Scripts | 755 | No sensitive data (templates only) |

## Network Security

### Default: Localhost Only
- Khoj binds to `127.0.0.1:9371`
- Not reachable from any other machine on the network

### Remote Mode (--remote flag)
- Binds to `0.0.0.0:9371`
- Intended for use with Tailscale VPN only
- No TLS — relies on Tailscale's WireGuard encryption
- No authentication beyond access code (anonymous mode enabled)

### API Security
- Khoj runs in `--anonymous-mode` — no per-request authentication
- Secured by localhost binding (default) or Tailscale (remote)
- Re-index API (`POST /api/update?t=markdown`) is unauthenticated
- Admin panel (`/server/admin`) uses Django session auth (email/password)

## Environment Variables
Stored in `~/.systemname/config/khoj.env`:
- `KHOJ_ADMIN_EMAIL` / `KHOJ_ADMIN_PASSWORD`
- `KHOJ_DJANGO_SECRET_KEY` — auto-generated 50-char URL-safe token
- `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` — optional cloud AI
- `POSTGRES_*` — database connection (no password by default)

## Stealth Properties
| Surface | Mitigation |
|---------|-----------|
| App icon / Dock | None — Khoj runs as CLI process |
| Menu bar | None — no status item |
| Launchpad | None — no .app bundle |
| Spotlight | `.metadata_never_index` markers |
| Finder | Dot-prefix hides directory |
| Process list | `khoj` process visible (unavoidable) |
| Network | Localhost only by default |
| Login items | LaunchAgent for watcher only (not Khoj itself) |
| Shell history | Launch command visible in history |

## Recommendations for Future Development
1. Add optional TOTP/time-based code rotation
2. Consider process name obfuscation for `khoj` process
3. Add rate limiting or lockout after N failed access code attempts
4. Support variable-length access codes
5. Add TLS for remote mode (self-signed cert generation)
6. Encrypt notes at rest (filesystem-level or application-level)
7. Clear shell history entry after launch
