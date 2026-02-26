# Configuration Specification

## Environment File

**Source:** `templates/khoj.env.template`
**Generated to:** `~/.systemname/config/khoj.env`
**Permissions:** 600

### Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KHOJ_ADMIN_EMAIL` | Yes | (set during install) | Admin panel login email |
| `KHOJ_ADMIN_PASSWORD` | Yes | (set during install) | Admin panel login password |
| `KHOJ_DJANGO_SECRET_KEY` | Yes | (auto-generated) | 50-char URL-safe token for Django sessions |
| `OPENAI_API_KEY` | No | (empty) | OpenAI API key for cloud AI |
| `ANTHROPIC_API_KEY` | No | (empty) | Anthropic API key for cloud AI |
| `POSTGRES_HOST` | Yes | `localhost` | PostgreSQL host |
| `POSTGRES_PORT` | Yes | `5432` | PostgreSQL port |
| `POSTGRES_DB` | Yes | `khoj` | Database name |
| `POSTGRES_USER` | Yes | (current macOS user) | Database user |
| `POSTGRES_PASSWORD` | No | (empty) | Database password (none by default) |
| `OPENAI_BASE_URL` | No | (commented out) | Ollama endpoint: `http://localhost:11434/v1/` |

### Loading Mechanism
The launch script (`logmem.sh`) loads the env file using:
```bash
set -a
source "$HOME/.systemname/config/khoj.env"
set +a
```
`set -a` auto-exports all variables so Khoj (and Django) can read them.

## Templating System

All scripts use sed-based placeholder replacement during installation:

| Placeholder | Replaced With |
|-------------|---------------|
| `SYSTEM_NAME` | User-chosen system name |
| `COMMAND_NAME` | User-chosen command name |
| `REPLACE_HOME` | `$HOME` path |
| `GDRIVE_NOT_CONFIGURED/SYSTEM_NAME` | Detected Google Drive path |
| `postgresql@17` | Detected PostgreSQL version |

## Directory Layout

```
~/.systemname/
├── files/                          # Note storage
│   └── .metadata_never_index       # Spotlight exclusion
├── .sys/
│   ├── .grvmap                     # SHA-256 access code hash (600)
│   ├── watcher.sh                  # Google Drive sync (755)
│   ├── reindex.sh                  # Manual re-index trigger (755)
│   ├── setgrove.sh                 # Access code setter (755)
│   └── import.log                  # Watcher activity log
├── config/
│   └── khoj.env                    # Environment config (600)
├── .gitignore                      # Contains "*"
└── .metadata_never_index           # Spotlight exclusion
```

## Port Assignments
| Service | Port | Configurable |
|---------|------|-------------|
| Khoj | 9371 | Hardcoded in launch script |
| PostgreSQL | 5432 | Via `POSTGRES_PORT` env var |
| Ollama | 11434 | Via `OPENAI_BASE_URL` env var |
