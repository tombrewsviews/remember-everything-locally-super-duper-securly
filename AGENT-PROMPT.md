# Local AI Memory System — Agent Setup Prompt

You are setting up a private, local AI memory system on macOS. This is built on top of Khoj (open-source AI second brain) but customised for privacy, stealth, and offline-first operation.

**This prompt is designed to be given to any AI agent.** Follow every step precisely. Do not skip steps. Execute commands and verify output before continuing.

---

## STEP 0 — Gather user preferences

Before doing anything, ask the user:

1. **System name** — a short word used as the hidden data folder name (e.g. `vault`, `brain`, `memex`, `echo`). Must be lowercase, no spaces. This will become `~/.systemname/`.
2. **Command name** — what they will type in terminal to launch the system (can be the same as system name, or something else). Must be lowercase, no spaces.
3. **Access code** — a 6-character code (letters, numbers, symbols) required to start the server. This is the only authentication. It will be stored as a SHA-256 hash, never in plaintext.
4. **Admin email** — email address for the Khoj admin panel login.
5. **Admin password** — password for the Khoj admin panel.
6. **AI model preference** — local (Ollama, free/offline) or cloud API (OpenAI/Anthropic)?

Store these values and use them throughout the rest of setup. Refer to the system by the chosen name, not by "logmem" or "Khoj".

---

## STEP 1 — Environment check

```bash
sw_vers
python3 --version
```

Python must be 3.10–3.12. If not:
```bash
brew install python@3.11
```

Install brew dependencies:
```bash
brew install pipx fswatch
pipx ensurepath
```

---

## STEP 2 — Install Khoj

```bash
pipx install khoj --python python3.11
which khoj
```

---

## STEP 3 — Install PostgreSQL and pgvector

```bash
brew install postgresql@17
brew install pgvector
brew services start postgresql@17
sleep 5
```

Link pgvector to PostgreSQL 17:
```bash
PG_EXT=$(find /opt/homebrew/Cellar/postgresql@17 -name "extension" -type d | grep share | head -1)
PG_LIB=$(find /opt/homebrew/Cellar/postgresql@17 -name "postgresql" -type d | grep lib | head -1)
PGVEC_SHARE="/opt/homebrew/opt/pgvector/share/postgresql@17/extension"
PGVEC_LIB="/opt/homebrew/opt/pgvector/lib/postgresql@17"
ln -sf "$PGVEC_SHARE/vector.control" "$PG_EXT/"
for f in "$PGVEC_SHARE/"vector*.sql; do ln -sf "$f" "$PG_EXT/"; done
ln -sf "$PGVEC_LIB/vector.dylib" "$PG_LIB/"
```

Create the database:
```bash
/opt/homebrew/opt/postgresql@17/bin/createdb -U $(whoami) khoj
```

---

## STEP 4 — Create directory structure

Using SYSTEM_NAME = the name chosen in Step 0:

```bash
mkdir -p ~/.SYSTEM_NAME/files
mkdir -p ~/.SYSTEM_NAME/.sys
mkdir -p ~/.SYSTEM_NAME/config
touch ~/.SYSTEM_NAME/.sys/import.log
echo "*" > ~/.SYSTEM_NAME/.gitignore
touch ~/.SYSTEM_NAME/.metadata_never_index
touch ~/.SYSTEM_NAME/files/.metadata_never_index
```

---

## STEP 5 — Create the access code file

Create `~/.SYSTEM_NAME/.sys/setcode.sh`:

```bash
#!/usr/bin/env bash
KEYMAP="$HOME/.SYSTEM_NAME/.sys/.keymap"
echo ""
read -s -p "Enter new 6-character access code: " INPUT_CODE
echo ""
read -s -p "Confirm access code: " CONFIRM_CODE
echo ""
if [ "$INPUT_CODE" != "$CONFIRM_CODE" ]; then echo "Codes do not match. Aborted."; exit 1; fi
if [ "${#INPUT_CODE}" -ne 6 ]; then echo "Code must be exactly 6 characters."; exit 1; fi
HASHED=$(echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}')
echo "$HASHED" > "$KEYMAP"
chmod 600 "$KEYMAP"
echo "Access code set."
```

Set the initial access code using the value from Step 0:
```bash
HASHED=$(echo -n "ACCESS_CODE" | shasum -a 256 | awk '{print $1}')
echo "$HASHED" > ~/.SYSTEM_NAME/.sys/.keymap
chmod 600 ~/.SYSTEM_NAME/.sys/.keymap
chmod +x ~/.SYSTEM_NAME/.sys/setcode.sh
```

---

## STEP 6 — Generate config file

Generate a secret key and create the config:

```bash
SECRET=$(python3.11 -c "import secrets; print(secrets.token_urlsafe(50))")
```

Write `~/.SYSTEM_NAME/config/app.env`:
```
KHOJ_ADMIN_EMAIL=ADMIN_EMAIL
KHOJ_ADMIN_PASSWORD=ADMIN_PASSWORD
KHOJ_DJANGO_SECRET_KEY=GENERATED_SECRET
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=khoj
POSTGRES_USER=YOUR_USERNAME
POSTGRES_PASSWORD=
# OPENAI_BASE_URL=http://localhost:11434/v1/
```

Set permissions:
```bash
chmod 600 ~/.SYSTEM_NAME/config/app.env
```

---

## STEP 7 — Create the launch command

Create `~/.local/bin/COMMAND_NAME`:

```bash
#!/usr/bin/env bash
KEYMAP="$HOME/.SYSTEM_NAME/.sys/.keymap"
if [ ! -f "$KEYMAP" ]; then echo "Not configured. Run: ~/.SYSTEM_NAME/.sys/setcode.sh"; exit 1; fi
read -s -p "" INPUT_CODE
HASHED=$(echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}')
STORED=$(cat "$KEYMAP")
if [ "$HASHED" != "$STORED" ]; then exit 0; fi
if [ -f "$HOME/.SYSTEM_NAME/config/app.env" ]; then set -a; source "$HOME/.SYSTEM_NAME/config/app.env"; set +a; fi
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
BIND_HOST="127.0.0.1"
if [[ "$1" == "--remote" ]]; then BIND_HOST="0.0.0.0"; fi
exec khoj --host "$BIND_HOST" --port 9371 --anonymous-mode 2>&1
```

```bash
chmod +x ~/.local/bin/COMMAND_NAME
```

Key behaviors:
- The prompt shows nothing — it silently waits for input
- Wrong code exits silently with code 0 — indistinguishable from success
- `--remote` flag binds to all interfaces for Tailscale access

---

## STEP 8 — Create the Google Drive watcher

Detect Google Drive:
```bash
GDRIVE_PATH=$(find ~/Library/CloudStorage -maxdepth 2 -name "My Drive" -type d 2>/dev/null | head -1)
```

If found, create the inbox folder:
```bash
mkdir -p "$GDRIVE_PATH/INBOX_FOLDER_NAME"
```

Create `~/.SYSTEM_NAME/.sys/watcher.sh` with the detected path. If not found, use a placeholder and tell the user to update it after installing Google Drive Desktop.

The watcher:
- Watches for new `.md` and `.txt` files in the inbox folder
- Copies them to `~/.SYSTEM_NAME/files/` with a timestamp prefix
- Triggers a Khoj re-index via `curl -X POST http://localhost:9371/api/update?t=markdown`

---

## STEP 9 — Create the reindex script

Create `~/.SYSTEM_NAME/.sys/reindex.sh`:
```bash
#!/usr/bin/env bash
curl -s -X POST "http://localhost:9371/api/update?t=markdown" > /dev/null 2>&1 \
  && echo "Re-index triggered" || echo "Server not running"
```

---

## STEP 10 — Install LaunchAgent

Create `~/Library/LaunchAgents/com.user.SYSTEM_NAME-watch.plist` using the expanded home path (not `~`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.user.SYSTEM_NAME-watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/USERNAME/.SYSTEM_NAME/.sys/watcher.sh</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/Users/USERNAME/.SYSTEM_NAME/.sys/import.log</string>
    <key>StandardErrorPath</key><string>/Users/USERNAME/.SYSTEM_NAME/.sys/import.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.user.SYSTEM_NAME-watch.plist
launchctl start com.user.SYSTEM_NAME-watch
```

---

## STEP 11 — Configure AI model

If user chose **Ollama**:
```bash
brew install ollama
ollama pull llama3.2
```

Uncomment the Ollama line in `app.env`:
```
OPENAI_BASE_URL=http://localhost:11434/v1/
```

If user chose **cloud API**, add the key to `app.env`.

---

## STEP 12 — First launch and admin setup

Start the system (pipe the access code to simulate user input):
```bash
echo "ACCESS_CODE" | COMMAND_NAME &
```

Wait ~30 seconds for startup. Then use a Python script to configure the default chat model in the database:

```python
import sys, os
sys.path.insert(0, '/Users/USERNAME/.local/pipx/venvs/khoj/lib/python3.11/site-packages')
import django
os.environ['DJANGO_SETTINGS_MODULE'] = 'khoj.app.settings'
os.environ['KHOJ_ADMIN_EMAIL'] = 'ADMIN_EMAIL'
os.environ['KHOJ_ADMIN_PASSWORD'] = 'ADMIN_PASSWORD'
os.environ['KHOJ_DJANGO_SECRET_KEY'] = 'SECRET_KEY'
os.environ['POSTGRES_HOST'] = 'localhost'
os.environ['POSTGRES_DB'] = 'khoj'
os.environ['POSTGRES_USER'] = 'USERNAME'
os.environ['OPENAI_BASE_URL'] = 'http://localhost:11434/v1/'
django.setup()
from khoj.database.models import ChatModel, ServerChatSettings, AiModelApi
api, _ = AiModelApi.objects.get_or_create(name='ollama-local', defaults={'api_key': 'ollama', 'api_base_url': 'http://localhost:11434/v1/'})
model, _ = ChatModel.objects.get_or_create(name='llama3.2', defaults={'model_type': 'openai', 'ai_model_api': api})
settings, _ = ServerChatSettings.objects.get_or_create(id=1)
settings.chat = model
settings.summarizer = model
settings.save()
print('Chat model configured:', model.name)
```

---

## STEP 13 — Verification

Run each check:

```bash
which COMMAND_NAME                          # command exists
ls -la ~/.SYSTEM_NAME/                      # directory structure
ls ~/.SYSTEM_NAME/.metadata_never_index     # spotlight excluded
ls -la ~/.SYSTEM_NAME/.sys/.keymap          # access code set
launchctl list | grep SYSTEM_NAME           # watcher running
```

Test the command with wrong code (should silently exit):
```bash
echo "xxxxxx" | COMMAND_NAME; echo "Exit: $?"  # should print Exit: 0 with no error
```

---

## STEP 14 — Print summary

Print a final summary showing:
- The command to start the system
- The URL to open in browser
- How to access from iPhone (Tailscale)
- How to add notes (direct drop or Google Drive)
- How to change access code
- Reminder to install Google Drive Desktop if not already installed

---

## Notes for the agent

- Never print the access code or any entered value to terminal
- Never log sensitive content — only filenames and timestamps
- If any step fails, stop and report the exact error
- If Google Drive is not installed, skip watcher config and clearly tell user what to do
- Do not create any `.app` bundles, menu bar items, or Login Items
- The word "khoj" should not appear in any file names, LaunchAgent labels, or user-facing output
