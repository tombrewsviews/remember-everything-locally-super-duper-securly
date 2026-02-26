# remember-everything-locally-super-duper-securly

Install and configure a private, local AI memory system on macOS. Fully automated setup using an AI agent.

## Usage

`/remember-everything-locally-super-duper-securly`

## What this skill does

Sets up a stealth, offline-first AI memory system on macOS with:
- A secret launch command the user chooses
- A hidden data directory with Spotlight exclusion
- A 6-character access code (SHA-256 hashed, never plaintext)
- Khoj as the AI backend with local Ollama or cloud API support
- Google Drive → auto-import pipeline for iPhone voice notes
- Tailscale support for iPhone remote access

## Instructions

When this skill is invoked, read the full `AGENT-PROMPT.md` from this repository and follow it precisely. If the file is not available, use the embedded instructions below.

Before doing anything else, ask the user these questions:

1. **System name** — a short lowercase word for the hidden data folder (e.g. `vault`, `brain`, `echo`). This becomes `~/.systemname/`.
2. **Command name** — what they type in terminal to launch the system (can match system name).
3. **Access code** — exactly 6 characters (letters, numbers, symbols). This is the only authentication.
4. **Admin email** — for the web admin panel.
5. **Admin password** — for the web admin panel.
6. **AI model** — local Ollama (free, offline) or cloud API key (OpenAI/Anthropic)?

Once you have all answers, proceed through the setup steps automatically without stopping unless a step fails. After each major step, verify it succeeded before continuing.

Key setup sequence:
1. Check macOS, Python 3.10-3.12, Homebrew
2. Install: pipx, fswatch, khoj (via pipx with python3.11), postgresql@17, pgvector
3. Link pgvector into PostgreSQL extension directory
4. Start PostgreSQL, create `khoj` database
5. Create `~/.SYSTEM_NAME/` directory structure with `.metadata_never_index` files
6. Hash access code with SHA-256, write to `~/.SYSTEM_NAME/.sys/.keymap`
7. Generate Django secret key, write `~/.SYSTEM_NAME/config/app.env`
8. Create `~/.local/bin/COMMAND_NAME` launcher script
9. Detect Google Drive path, create inbox folder, write watcher script
10. Install LaunchAgent for watcher (use expanded `$HOME` path, not `~`)
11. Install Ollama + pull model if chosen
12. Start server, configure default chat model via Python/Django shell
13. Run verification checks
14. Print final summary

Critical behaviors to implement exactly:
- Launch command prompts with NO text — silently waits for access code input
- Wrong access code: `exit 0` with no output — silent, indistinguishable from success
- `--remote` flag binds to `0.0.0.0` instead of `127.0.0.1`
- Never use "khoj" in LaunchAgent labels, command names, or user-facing output
- Never log the access code or admin password anywhere

After setup is complete, print:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Setup complete.

  Start:         COMMAND_NAME
  Remote start:  COMMAND_NAME --remote
  Open:          http://localhost:9371
  Change code:   ~/.SYSTEM_NAME/.sys/setcode.sh

  Drop notes into: ~/.SYSTEM_NAME/files/
  Or via Google Drive inbox folder (auto-imported)

  iPhone access: start with --remote, connect Tailscale,
  open http://[your-tailscale-ip]:9371 in Safari
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
