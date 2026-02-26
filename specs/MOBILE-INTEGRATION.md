# Mobile Integration Specification

## Overview
iPhone access is supported via two mechanisms:
1. **Google Drive sync** — for pushing voice notes and text to the system
2. **Tailscale VPN** — for accessing the Khoj web UI from iPhone

## Google Drive Voice Note Pipeline

```
iPhone (iOS Shortcut)
  ↓ Dictate Text (on-device)
  ↓ Prepend date header
  ↓ Save as .md file with timestamp name
  ↓
Google Drive (cloud sync)
  ↓ Syncs to Mac via Google Drive Desktop
  ↓
~/Library/CloudStorage/GoogleDrive-*/My Drive/<systemname>/
  ↓
fswatch (watcher.sh as LaunchAgent)
  ↓
~/.systemname/files/mobile_YYYYMMDD_HHMMSS_filename.md
  ↓
Khoj re-index (POST /api/update?t=markdown)
```

### iOS Shortcut Design
Recommended shortcut steps:
1. **Dictate Text** — on-device speech recognition (no internet required)
2. **Text** — prepend current date/time as markdown header
3. **Make Text File** — named with current timestamp
4. **Save File** — to Google Drive inbox folder

### Latency
- Speech-to-text: instant (on-device)
- Google Drive upload: depends on network
- Google Drive Desktop sync: typically 1-30 seconds
- fswatch detection: near-instant
- File copy + re-index: < 2 seconds
- **Total expected:** 5-60 seconds from dictation to searchable

## Tailscale Remote Access

### Setup
1. Install Tailscale on Mac and iPhone
2. Log in with same Tailscale account on both
3. Start system with `--remote` flag
4. Access `http://<mac-tailscale-ip>:9371` from iPhone Safari

### Security
- Tailscale uses WireGuard encryption (end-to-end)
- No TLS on the Khoj server itself
- Anonymous mode — no per-request authentication
- Access restricted to Tailscale network members only

### Limitations
- Requires `--remote` flag at launch (can't switch dynamically)
- No push notifications for new note imports
- Web UI not optimized for mobile (Khoj's default UI)
- No offline access from iPhone — requires active Tailscale connection
- No selective sync — all notes are accessible or none

## Supported File Formats
| Format | Source | Handling |
|--------|--------|----------|
| `.md` | Google Drive import | Copied and indexed |
| `.txt` | Google Drive import | Copied and indexed |
| Other | Google Drive import | Silently ignored |

## Future Considerations
- Native iOS app or PWA wrapper
- iCloud Drive support as alternative to Google Drive
- Push notifications via Tailscale webhook
- Offline-first mobile client with sync
- Support for audio files (transcription pipeline)
- Support for images (OCR pipeline)
