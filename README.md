# remember-everything-locally-super-duper-securly

A private, local AI memory system for macOS. Built on top of [Khoj](https://github.com/khoj-ai/khoj) — hardened for privacy, stealth, and offline-first operation.

> **Recommended:** Use the included Claude Code skill to set this up automatically with an AI agent instead of following these manual steps. See [Agentic Setup](#agentic-setup) below.

## What it does

- Launched via a **secret command you choose** — no app icon, no menu bar item, nothing visible
- All data lives in a **hidden folder you name** — never indexed by Spotlight
- A **6-character access code** is required before the server launches — wrong code silently exits with no error
- 100% local — no Docker, no cloud
- Voice notes dictated on iPhone → Google Drive → auto-imported into your memory database
- Accessible from iPhone via Tailscale when away from home WiFi
- Chat with your notes using a local AI model (Ollama) or any API (OpenAI, Anthropic)

---

## Agentic Setup

The fastest way to set this up is to let an AI agent do it for you.

### With Claude Code

1. Install [Claude Code](https://claude.ai/code)
2. Copy the file `skill.md` from this repo into your Claude skills folder:
   ```bash
   cp skill.md ~/.claude/skills/remember-everything-locally-super-duper-securly.md
   ```
3. Open Claude Code in any directory and run:
   ```
   /remember-everything-locally-super-duper-securly
   ```
4. Claude will ask you a few questions (system name, command name, access code) and handle everything else automatically.

### With any AI agent

Paste the contents of `AGENT-PROMPT.md` directly into any AI assistant (ChatGPT, Gemini, Cursor, etc.) and it will guide you through the setup step by step.

---

## Manual Install

If you prefer to install without an AI agent:

```bash
git clone https://github.com/your-username/remember-everything-locally-super-duper-securly.git
cd remember-everything-locally-super-duper-securly
chmod +x install.sh
./install.sh
```

The installer will ask you to choose:
- A **system name** (e.g. `vault`, `brain`, `memex`) — used as your hidden data folder (`~/.vault/`)
- A **command name** (e.g. `vault`, `brain`, `mem`) — what you type in terminal to launch it
- A **6-character access code** — required every time you start the server

Then it will automatically:
1. Install Khoj, PostgreSQL, pgvector, fswatch via Homebrew
2. Create your hidden directory structure with Spotlight exclusion
3. Detect your Google Drive path and create the inbox folder
4. Generate a secure secret key
5. Install your command to `~/.local/bin`
6. Install a background watcher for Google Drive
7. Set your access code

## Usage

```bash
yoursystemname           # start (localhost only)
yoursystemname --remote  # start (accessible via Tailscale from iPhone)
```

After starting, open `http://localhost:9371` in your browser.

Change your access code at any time:
```bash
~/.yoursystemname/.sys/setcode.sh
```

Force a re-index of your notes:
```bash
~/.yoursystemname/.sys/reindex.sh
```

## First run setup (after install)

1. Start your system and go to `http://localhost:9371/server/admin`
2. Log in with the admin email/password you set during install
3. Go to **Chat models** → add your AI model:
   - **Ollama (free, offline):** `brew install ollama && ollama pull llama3.2`
     - Model name: `llama3.2`, Type: `OpenAI`, API base: `http://localhost:11434/v1/`
   - **OpenAI / Anthropic:** add your key to `~/.yoursystemname/config/khoj.env` and restart
4. Go to **Content sources** → add `~/.yoursystemname/files` as a watched directory

## Adding notes

**Drop files directly:**
```bash
cp my-note.md ~/.yoursystemname/files/
~/.yoursystemname/.sys/reindex.sh
```

**Via Google Drive (auto-imported):**
Drop any `.md` or `.txt` file into your Google Drive inbox folder. The watcher copies it to your files directory and triggers a re-index automatically.

**Via iPhone voice notes (iOS Shortcuts):**

Create an iOS Shortcut:
1. **Dictate Text** — on-device, no internet needed
2. **Text** — prepend a date header using current date variable
3. **Make Text File** — named with current timestamp
4. **Save File** → Google Drive → your inbox folder

## iPhone remote access

1. Install [Tailscale](https://tailscale.com) on your Mac and iPhone
2. Log in with the same account on both
3. Start your system with `--remote` flag
4. On iPhone Safari: `http://[your-mac-tailscale-ip]:9371`

## Directory structure

```
~/.yoursystemname/
  files/              ← all your notes (markdown/text)
  .sys/
    .keymap           ← hashed access code (SHA-256, never plaintext)
    watcher.sh        ← Google Drive → files/ sync watcher
    reindex.sh        ← trigger re-index
    setcode.sh        ← set or change access code
    import.log        ← log of auto-imported files
  config/
    app.env           ← environment variables (chmod 600)
```

## Privacy design

- Access code stored as SHA-256 hash only — never plaintext
- Wrong code: silent exit with code 0, indistinguishable from success
- Data directory excluded from Spotlight indexing
- Server binds to `127.0.0.1` by default — not reachable from network unless `--remote` used
- No login items, no Launchpad entries, no visible app bundles

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.user.yourname-watch.plist
rm ~/Library/LaunchAgents/com.user.yourname-watch.plist
rm ~/.local/bin/yoursystemname
rm -rf ~/.yoursystemname
pipx uninstall khoj  # optional
```

## License

MIT
