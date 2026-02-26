# Google Drive Watcher Specification

**Source:** `scripts/watcher.sh` (42 lines)

## Purpose
Background service that monitors a Google Drive inbox folder for new files, imports them into the local note storage, and triggers Khoj re-indexing.

## Architecture

```
Google Drive Desktop (cloud sync)
  ↓
~/Library/CloudStorage/GoogleDrive-*/My Drive/<systemname>/
  ↓
fswatch (Created | Updated | MovedTo events)
  ↓
Copy to ~/.systemname/files/ with timestamp prefix
  ↓
Delete from inbox (best effort)
  ↓
POST /api/update?t=markdown → Khoj re-index
```

## Service Management
- Runs as a **macOS LaunchAgent** (`com.user.<systemname>-watch`)
- Starts automatically at login (`RunAtLoad: true`)
- Auto-restarts on crash (`KeepAlive: true`)
- Logs to `~/.systemname/.sys/import.log`

## File Processing Rules

### Accepted File Types
- `.md` (Markdown)
- `.txt` (Plain text)
- All other extensions are silently ignored

### File Naming
Imported files are renamed with a timestamp prefix:
```
mobile_20240115_143022_original-filename.md
```
Format: `mobile_YYYYMMDD_HHMMSS_<original_name>`

### Event Handling
| fswatch Event | Action |
|---------------|--------|
| Created | Process file |
| Updated | Process file |
| MovedTo | Process file |
| Other events | Ignored |

## Processing Steps
1. fswatch detects new file in inbox
2. Check file extension — skip if not `.md` or `.txt`
3. Wait 1 second (`sleep 1`) — allow file write to complete
4. Copy to `~/.systemname/files/` with timestamp prefix
5. Delete original from inbox (suppress errors — Google Drive may resist)
6. Trigger Khoj re-index via `curl -s -X POST` (suppress errors — server may not be running)

## Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `GDRIVE_INBOX` | Set during install | Google Drive inbox path |
| `SYS_FILES` | `~/.systemname/files` | Note storage directory |
| `IMPORT_LOG` | `~/.systemname/.sys/import.log` | Log file path |
| `KHOJ_PORT` | `9371` | Khoj server port |

## Error Handling
- If Google Drive not configured: logs error and exits
- If file copy fails: no explicit handling (would be logged via `set -e` if enabled, but it's not)
- If inbox delete fails: silently suppressed (`rm ... 2>/dev/null || true`)
- If Khoj not running: re-index curl silently fails

## LaunchAgent Configuration
**Source:** `templates/launchagent.plist`

```xml
Label: com.user.<systemname>-watch
Program: /bin/bash ~/.systemname/.sys/watcher.sh
RunAtLoad: true
KeepAlive: true
Stdout/Stderr: ~/.systemname/.sys/import.log
```

## Known Issues
- No deduplication — same file updated twice creates two copies
- 1-second sleep is arbitrary — large files may not finish writing
- No file size limits — very large files could cause issues
- Google Drive sync conflicts not handled
- No health monitoring or alerting
- fswatch path hardcoded to `/opt/homebrew/bin/fswatch`
- No support for subdirectories in inbox
- Log file grows unbounded
