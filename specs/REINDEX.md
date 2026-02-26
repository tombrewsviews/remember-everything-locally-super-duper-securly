# Re-index Specification

**Source:** `scripts/reindex.sh` (6 lines)

## Purpose
Manual trigger to force Khoj to re-index all markdown files in the notes directory.

## Implementation
```bash
curl -s -X POST "http://localhost:9371/api/update?t=markdown"
```

## Behavior
- Sends HTTP POST to Khoj's update API
- `?t=markdown` — specifies content type to re-index
- Success: prints "Re-index triggered"
- Failure (server not running): prints "Khoj not running on port 9371"

## Use Cases
- After manually adding/editing files in `~/.systemname/files/`
- After bulk import of notes
- When search results seem stale
- Debugging indexing issues

## Dependencies
- Khoj server must be running on port 9371
- `curl` must be available (standard on macOS)
