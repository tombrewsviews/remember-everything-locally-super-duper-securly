# Launch System Specification

**Source:** `scripts/logmem.sh` (43 lines)

## Purpose
Entry point for the entire system. Validates the access code, loads configuration, and starts the Khoj server.

## Execution Flow

```
User types command
  ↓
Check .grvmap exists → error if not (unconfigured)
  ↓
Silent prompt (read -s -p "")
  ↓
SHA-256 hash input → compare with stored hash
  ↓
Mismatch → exit 0 (silent)
  ↓
Match → source khoj.env (set -a / set +a)
  ↓
Add PostgreSQL to PATH
  ↓
Parse --remote flag → 127.0.0.1 or 0.0.0.0
  ↓
exec khoj --host <bind> --port 9371 --anonymous-mode
```

## Command Line Interface

```bash
<command_name>            # Start locally (127.0.0.1:9371)
<command_name> --remote   # Start remotely (0.0.0.0:9371)
```

## Key Behaviors
- **Silent prompt:** No text displayed — user must know to type their code
- **Silent failure:** Wrong code exits with code 0, identical to normal exit
- **exec replacement:** Process replaces shell — no parent process left behind
- **Environment loading:** Uses `set -a` to auto-export all variables from `khoj.env`
- **PostgreSQL PATH:** Hardcoded to `/opt/homebrew/opt/postgresql@17/bin`

## Configuration Dependencies
| File | Required | Purpose |
|------|----------|---------|
| `~/.systemname/.sys/.grvmap` | Yes | Access code hash |
| `~/.systemname/config/khoj.env` | No (optional) | Runtime environment variables |

## Khoj Server Parameters
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--host` | `127.0.0.1` or `0.0.0.0` | Network binding |
| `--port` | `9371` | HTTP port |
| `--anonymous-mode` | (flag) | Skip per-request auth |

## Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Wrong access code (intentional — stealth) |
| 0 | Normal server shutdown |
| 1 | `.grvmap` not found (unconfigured system) |

## Known Issues
- PostgreSQL version hardcoded to `@17` in template (installer replaces it, but template shows 17)
- No graceful shutdown handling for the Khoj process
- No PID file creation for process management
- stderr merged with stdout via `2>&1`
