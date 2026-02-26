# Installer Specification

**Source:** `install.sh` (261 lines)

## Purpose
Automated end-to-end setup of the local AI memory system on macOS. Interactive — prompts for customization, then handles all dependency installation, directory creation, config generation, and service registration.

## Prerequisites
- macOS (Darwin kernel check)
- Homebrew installed

## Execution Flow

### Phase 1: Validation & Input
1. **OS check** — exits with error if not macOS
2. **Homebrew check** — exits with error if not installed
3. **System name prompt** — lowercase alphanumeric + hyphens/underscores, becomes `~/.name/`
4. **Command name prompt** — defaults to system name, becomes CLI launch command

### Phase 2: Dependency Installation
5. **Python detection** — scans for 3.12, 3.11, 3.10 in order; installs 3.11 if none found
6. **Brew packages** — `pipx`, `fswatch`, `tailscale` (cask)
7. **Khoj** — installed via `pipx install khoj --python <detected_python>`
8. **PostgreSQL** — checks for 17 or 16; installs 17 if neither found
9. **pgvector** — installed and symlinked into PostgreSQL extension directory
10. **Database** — PostgreSQL service started, `khoj` database created

### Phase 3: Directory Structure
11. Creates `~/.systemname/files/` — note storage
12. Creates `~/.systemname/.sys/` — internal scripts and state
13. Creates `~/.systemname/config/` — environment config
14. Places `.metadata_never_index` in root and `files/` for Spotlight exclusion
15. Places `.gitignore` with `*` to prevent accidental commits

### Phase 4: Script Installation
16. **setgrove.sh** — templated with system name, placed in `.sys/`
17. **reindex.sh** — templated with system name, placed in `.sys/`
18. **watcher.sh** — templated with system name + Google Drive path, placed in `.sys/`

### Phase 5: Configuration Generation
19. **khoj.env** — generated with:
    - Random Django secret key (50-char URL-safe token)
    - Current macOS username as PostgreSQL user
    - Placeholder fields for admin email/password and API keys
    - `chmod 600` applied
20. **Google Drive detection** — scans `~/Library/CloudStorage` for "My Drive"; creates inbox subfolder if found

### Phase 6: Command & Service Installation
21. **Launch script** — `logmem.sh` templated and placed at `~/.local/bin/<command_name>`
22. **PATH update** — appends to `.zshrc` and `.bashrc` if needed
23. **LaunchAgent** — `launchagent.plist` templated and loaded via `launchctl`

### Phase 7: Credential Setup
24. **Access code** — runs `setgrove.sh` interactively (6-char, SHA-256 hashed)
25. **Admin credentials** — prompts for email + password, written to `khoj.env`

## Templating System
All scripts use `SYSTEM_NAME`, `COMMAND_NAME`, `REPLACE_HOME`, and `GDRIVE_NOT_CONFIGURED/SYSTEM_NAME` as placeholders, replaced via `sed` during install.

## Generated Artifacts

| Artifact | Path | Permissions |
|----------|------|-------------|
| Data directory | `~/.systemname/` | Default |
| Note storage | `~/.systemname/files/` | Default |
| Access code hash | `~/.systemname/.sys/.grvmap` | 600 |
| Import log | `~/.systemname/.sys/import.log` | Default |
| Environment config | `~/.systemname/config/khoj.env` | 600 |
| Launch command | `~/.local/bin/<command>` | 755 |
| LaunchAgent | `~/Library/LaunchAgents/com.user.<name>-watch.plist` | Default |

## Error Handling
- `set -e` at top — any command failure aborts the script
- PostgreSQL/pgvector linking failures print warnings but continue
- Google Drive not found prints instructions but continues
- Database creation uses `|| echo` to handle "already exists" case

## Known Limitations
- No rollback on partial failure
- No uninstall path within the installer (documented separately in README)
- pgvector linking is fragile across Homebrew version changes
- Google Drive detection relies on directory naming conventions
