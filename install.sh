#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
#  remember-everything-locally-super-duper-securly — local AI memory system
#  installer for macOS
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helper: status printer ────────────────────
ok()   { echo "  ✓ $1"; }
info() { echo "  ⟶ $1"; }
warn() { echo "  ⚠ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║   remember-everything-locally-super-duper-securly            ║"
echo "  ║   Private local AI memory system for macOS                   ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  This installer will set up everything you need:"
echo ""
echo "    • Khoj (AI memory server) + PostgreSQL database"
echo "    • Ollama + a local AI model (runs 100% on your machine)"
echo "    • Hammerspoon (global hotkeys for instant memory capture)"
echo "    • sox + whisper-cpp (audio recording + local transcription)"
echo "    • A hidden, Spotlight-excluded data folder"
echo "    • A secret launch command with access code protection"
echo ""
echo "  No data ever leaves your machine. No cloud. No Docker."
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# ── 1. Check macOS ──────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  fail "This installer requires macOS."
fi
ok "macOS detected"

# ── 2. Check Homebrew ───────────────────────
if ! command -v brew &>/dev/null; then
  echo ""
  echo "  Homebrew is required but not installed."
  echo "  Install it by running this in your terminal:"
  echo ""
  echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo ""
  echo "  Then re-run this installer."
  exit 1
fi
ok "Homebrew found"

# ── 3. Gather user preferences ──────────────
echo "  Let's personalise your setup."
echo ""

while true; do
  read -p "  System name (e.g. vault, brain, echo) — becomes ~/.name/: " SYS_NAME
  SYS_NAME="${SYS_NAME// /}"   # strip spaces
  SYS_NAME="$(echo "$SYS_NAME" | tr '[:upper:]' '[:lower:]')"  # lowercase
  if [[ -z "$SYS_NAME" ]]; then
    echo "  System name cannot be empty. Try again."
  elif [[ ! "$SYS_NAME" =~ ^[a-z0-9_-]+$ ]]; then
    echo "  Use only lowercase letters, numbers, hyphens, or underscores."
  else
    break
  fi
done

while true; do
  read -p "  Command name (what you type to launch it) [$SYS_NAME]: " CMD_NAME
  CMD_NAME="${CMD_NAME// /}"
  CMD_NAME="$(echo "$CMD_NAME" | tr '[:upper:]' '[:lower:]')"
  CMD_NAME="${CMD_NAME:-$SYS_NAME}"   # default to system name
  if [[ ! "$CMD_NAME" =~ ^[a-z0-9_-]+$ ]]; then
    echo "  Use only lowercase letters, numbers, hyphens, or underscores."
  else
    break
  fi
done

SYS_DIR="$HOME/.$SYS_NAME"
SYS_BIN="$HOME/.local/bin/$CMD_NAME"

echo ""
echo "  Data folder:  ~/.$SYS_NAME/"
echo "  Command:      $CMD_NAME"
echo ""

echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Installing dependencies (this may take a few minutes)..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# ── 4. Check Python 3.10–3.12 ───────────────
PYTHON_BIN=""
for v in python3.12 python3.11 python3.10; do
  if command -v $v &>/dev/null; then
    PYTHON_BIN=$(command -v $v)
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  info "Installing Python 3.11..."
  brew install python@3.11
  PYTHON_BIN=$(command -v python3.11)
fi
ok "Python: $($PYTHON_BIN --version 2>&1)"

# ── 5. Install brew dependencies ────────────
info "Installing core tools (pipx, fswatch, tailscale)..."
brew install pipx fswatch 2>/dev/null || true
brew install --cask tailscale 2>/dev/null || true
pipx ensurepath 2>/dev/null
ok "Core tools installed"

# ── 6. Install Khoj ─────────────────────────
if ! command -v khoj &>/dev/null; then
  info "Installing Khoj (AI memory server)..."
  pipx install khoj --python "$PYTHON_BIN"
fi
ok "Khoj installed"

# ── 7. Install PostgreSQL + pgvector ────────
PG_VERSION=""
for v in 17 16; do
  if brew list postgresql@$v &>/dev/null 2>&1; then
    PG_VERSION=$v
    break
  fi
done
if [[ -z "$PG_VERSION" ]]; then
  info "Installing PostgreSQL 17..."
  brew install postgresql@17
  PG_VERSION=17
fi
PG_BIN="/opt/homebrew/opt/postgresql@${PG_VERSION}/bin"
export PATH="$PG_BIN:$PATH"
ok "PostgreSQL $PG_VERSION installed"

info "Installing pgvector (vector search)..."
brew install pgvector 2>/dev/null || true
PGVEC_SHARE="/opt/homebrew/opt/pgvector/share/postgresql@${PG_VERSION}/extension"
PGVEC_LIB="/opt/homebrew/opt/pgvector/lib/postgresql@${PG_VERSION}"
PG_EXT=$(find /opt/homebrew/Cellar/postgresql@${PG_VERSION} -name "extension" -type d | grep share | head -1)
PG_LIB=$(find /opt/homebrew/Cellar/postgresql@${PG_VERSION} -name "postgresql" -type d | grep lib | head -1)

if [[ -d "$PGVEC_SHARE" && -d "$PG_EXT" ]]; then
  ln -sf "$PGVEC_SHARE/vector.control" "$PG_EXT/vector.control" 2>/dev/null || true
  for f in "$PGVEC_SHARE/"vector*.sql; do
    ln -sf "$f" "$PG_EXT/$(basename $f)" 2>/dev/null || true
  done
  ln -sf "$PGVEC_LIB/vector.dylib" "$PG_LIB/vector.dylib" 2>/dev/null || true
  ok "pgvector linked to PostgreSQL $PG_VERSION"
else
  warn "Could not link pgvector automatically. You may need to do this manually."
fi

brew services start postgresql@${PG_VERSION} 2>/dev/null || true
sleep 3

"$PG_BIN/createdb" -U "$(whoami)" khoj 2>/dev/null || true
ok "Database 'khoj' ready"

# ── 8. Create directory structure ───────────
info "Creating ~/.$SYS_NAME/ directory structure..."
mkdir -p "$SYS_DIR/files"
mkdir -p "$SYS_DIR/.sys"
mkdir -p "$SYS_DIR/config"
touch "$SYS_DIR/.sys/import.log"
echo "*" > "$SYS_DIR/.gitignore"
touch "$SYS_DIR/.metadata_never_index"
touch "$SYS_DIR/files/.metadata_never_index"

# ── 9. Copy scripts (stamp in system name) ───
sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/scripts/setgrove.sh" > "$SYS_DIR/.sys/setgrove.sh"
sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/scripts/reindex.sh"  > "$SYS_DIR/.sys/reindex.sh"
chmod +x "$SYS_DIR/.sys/setgrove.sh"
chmod +x "$SYS_DIR/.sys/reindex.sh"

# ── 10. Detect Google Drive ──────────────────
GDRIVE_INBOX="GDRIVE_NOT_CONFIGURED/$SYS_NAME"
GDRIVE_PATH=$(find ~/Library/CloudStorage -maxdepth 2 -name "My Drive" -type d 2>/dev/null | grep -i "gmail\|google" | head -1)
if [[ -n "$GDRIVE_PATH" ]]; then
  mkdir -p "$GDRIVE_PATH/$SYS_NAME"
  GDRIVE_INBOX="$GDRIVE_PATH/$SYS_NAME"
  ok "Google Drive found — auto-import folder created"
else
  warn "Google Drive Desktop not detected (optional — you can set it up later)"
fi

sed \
  -e "s|SYSTEM_NAME|$SYS_NAME|g" \
  -e "s|GDRIVE_NOT_CONFIGURED/$SYS_NAME|$GDRIVE_INBOX|g" \
  "$SCRIPT_DIR/scripts/watcher.sh" > "$SYS_DIR/.sys/watcher.sh"
chmod +x "$SYS_DIR/.sys/watcher.sh"

# ── 11. Generate config ──────────────────────
SECRET_KEY=$("$PYTHON_BIN" -c "import secrets; print(secrets.token_urlsafe(50))")
DB_USER="$(whoami)"

cat > "$SYS_DIR/config/khoj.env" << EOF
# Khoj runtime config — generated by remember-everything-locally-super-duper-securly — do not share or commit this file
KHOJ_ADMIN_EMAIL=
KHOJ_ADMIN_PASSWORD=
KHOJ_DJANGO_SECRET_KEY=${SECRET_KEY}
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=khoj
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=
# Uncomment to use a local Ollama instance
# OPENAI_BASE_URL=http://localhost:11434/v1/
EOF
chmod 600 "$SYS_DIR/config/khoj.env"

# ── 12. Install launch command ───────────────
mkdir -p "$HOME/.local/bin"
sed \
  -e "s|SYSTEM_NAME|$SYS_NAME|g" \
  -e "s|COMMAND_NAME|$CMD_NAME|g" \
  -e "s|postgresql@17|postgresql@${PG_VERSION}|g" \
  "$SCRIPT_DIR/scripts/logmem.sh" > "$SYS_BIN"
chmod +x "$SYS_BIN"

if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
fi

# ── 13. Install LaunchAgent ──────────────────
PLIST="$HOME/Library/LaunchAgents/com.user.$SYS_NAME-watch.plist"
sed \
  -e "s|REPLACE_HOME|$HOME|g" \
  -e "s|SYSTEM_NAME|$SYS_NAME|g" \
  "$SCRIPT_DIR/templates/launchagent.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
launchctl start "com.user.$SYS_NAME-watch" 2>/dev/null || true

echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Installing AI model (runs 100% locally on your machine)..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# ── 14a. Install Ollama + local AI model ──────
if ! command -v ollama &>/dev/null; then
  info "Installing Ollama (local AI runtime)..."
  brew install --cask ollama
fi
ok "Ollama installed"

# Start Ollama service if not running
if ! pgrep -q "[Oo]llama"; then
  info "Starting Ollama service..."
  open -a Ollama 2>/dev/null || true
  # Wait for Ollama to be ready (up to 30 seconds)
  for i in $(seq 1 30); do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  ok "Ollama service running"
else
  warn "Ollama service didn't start. You may need to open Ollama.app manually."
fi

# Pull a general-purpose chat model (best for memory/search/chat)
OLLAMA_MODEL="mistral"
if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
  ok "AI model '$OLLAMA_MODEL' already downloaded"
else
  echo ""
  info "Downloading AI model '$OLLAMA_MODEL' (~4 GB)..."
  echo "     This is a one-time download. The model runs 100% locally."
  echo "     It may take a few minutes depending on your internet speed."
  echo ""
  ollama pull "$OLLAMA_MODEL"
  ok "AI model '$OLLAMA_MODEL' downloaded"
fi

# Verify the model is usable
if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
  ok "AI model '$OLLAMA_MODEL' verified and ready"
else
  warn "Could not verify model '$OLLAMA_MODEL'. You can pull it manually: ollama pull $OLLAMA_MODEL"
fi

# Pre-configure Khoj to use Ollama
sed -i '' "s|^# OPENAI_BASE_URL=.*|OPENAI_BASE_URL=http://localhost:11434/v1/|" "$SYS_DIR/config/khoj.env"
ok "Khoj configured to use Ollama"

echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Installing memory capture tools..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# ── 14b. Install memory capture dependencies ───

# Hammerspoon — provides global keyboard shortcuts
if ! brew list --cask hammerspoon &>/dev/null 2>&1; then
  info "Installing Hammerspoon (global hotkeys)..."
  brew install --cask hammerspoon
fi
ok "Hammerspoon installed (provides Ctrl+Opt+T/S/A hotkeys)"

# sox — records audio from microphone
if ! command -v sox &>/dev/null; then
  info "Installing sox (audio recorder)..."
  brew install sox
fi
ok "sox installed (microphone recording)"

# whisper-cpp — local speech-to-text transcription (binary is called whisper-cli)
if ! command -v whisper-cli &>/dev/null; then
  info "Installing whisper-cpp (local speech-to-text)..."
  brew install whisper-cpp
fi
ok "whisper-cpp installed (offline transcription)"

# ── 15. Download whisper model ─────────────────
WHISPER_MODEL="$SYS_DIR/.sys/ggml-base.en.bin"
if [[ ! -f "$WHISPER_MODEL" ]]; then
  info "Downloading Whisper speech model (~140 MB, one-time)..."
  curl -L --progress-bar \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" \
    -o "$WHISPER_MODEL"
fi
if [[ -f "$WHISPER_MODEL" ]]; then
  ok "Whisper speech-to-text model ready"
else
  warn "Whisper model download failed. Voice transcription won't work."
  echo "     Re-run install.sh or manually download to: $WHISPER_MODEL"
fi

# ── 16. Create memories directory ──────────────
mkdir -p "$SYS_DIR/files/memories/assets"
touch "$SYS_DIR/files/memories/.metadata_never_index"
touch "$SYS_DIR/files/memories/assets/.metadata_never_index"

# ── 17. Install capture scripts ────────────────
for script in capture-common.sh capture-text.sh capture-screen.sh capture-audio.sh; do
  sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/scripts/$script" > "$SYS_DIR/.sys/$script"
  chmod +x "$SYS_DIR/.sys/$script"
done

# Compile image description tool (OCR via macOS Vision framework)
if swiftc -O -o "$SYS_DIR/.sys/describe-image" "$SCRIPT_DIR/scripts/describe-image.swift" 2>/dev/null; then
  chmod +x "$SYS_DIR/.sys/describe-image"
  ok "Screenshot OCR tool compiled"
else
  warn "Could not compile OCR tool — screenshots won't have text extraction"
fi

# ── 18. Deploy Hammerspoon module ──────────────
HS_DIR="$HOME/.hammerspoon"
mkdir -p "$HS_DIR"

# Template and install memcapture.lua
sed "s|SYSTEM_NAME|$SYS_NAME|g" "$SCRIPT_DIR/templates/memcapture.lua" > "$HS_DIR/memcapture.lua"

# Add require lines to init.lua if not already present
HS_INIT="$HS_DIR/init.lua"
if [[ ! -f "$HS_INIT" ]]; then
  cat > "$HS_INIT" << 'HSINIT'
require("hs.ipc")
require("memcapture")
HSINIT
else
  # Ensure hs.ipc is loaded (needed for CLI debugging)
  if ! grep -q 'require("hs.ipc")' "$HS_INIT"; then
    tmpinit="$(mktemp)"
    echo 'require("hs.ipc")' > "$tmpinit"
    cat "$HS_INIT" >> "$tmpinit"
    mv "$tmpinit" "$HS_INIT"
  fi
  if ! grep -q 'require("memcapture")' "$HS_INIT"; then
    echo '' >> "$HS_INIT"
    echo 'require("memcapture")' >> "$HS_INIT"
  fi
fi

# Hide Hammerspoon dock icon via defaults
defaults write org.hammerspoon.Hammerspoon MJShowDockIconKey -bool false 2>/dev/null || true

ok "Hammerspoon hotkey module deployed"

# ── 19. Launch Hammerspoon + guide permissions ──
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Setting up global hotkeys (Hammerspoon)..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# Launch Hammerspoon (or reload if already running)
if pgrep -q Hammerspoon; then
  open -g hammerspoon://reload 2>/dev/null || true
  ok "Hammerspoon reloaded"
else
  info "Launching Hammerspoon for the first time..."
  open -a Hammerspoon 2>/dev/null || true
  sleep 3
  ok "Hammerspoon launched"
fi

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │                                                              │"
echo "  │   macOS will ask you to grant permissions.                   │"
echo "  │   Please grant ALL THREE now so hotkeys work immediately:    │"
echo "  │                                                              │"
echo "  │   Open:  System Settings → Privacy & Security                │"
echo "  │                                                              │"
echo "  │   1. Accessibility     → toggle ON for Hammerspoon           │"
echo "  │      (needed for: Ctrl+Opt+T text, Ctrl+Opt+S screenshot,   │"
echo "  │       Ctrl+Opt+A audio — ALL hotkeys require this)           │"
echo "  │                                                              │"
echo "  │   2. Screen Recording  → toggle ON for Hammerspoon           │"
echo "  │      (needed for: Ctrl+Opt+S screenshot capture)             │"
echo "  │                                                              │"
echo "  │   3. Microphone        → toggle ON for Hammerspoon AND sox   │"
echo "  │      (needed for: Ctrl+Opt+A voice recording)                │"
echo "  │                                                              │"
echo "  │   If macOS didn't prompt you, open System Settings now       │"
echo "  │   and add Hammerspoon manually to each category above.       │"
echo "  │                                                              │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
read -p "  Press Enter when you've granted the permissions (or to skip for now)... "

# ── 20. Verify all dependencies ───────────────
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Verifying installation..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

INSTALL_OK=true

# Core services
command -v khoj &>/dev/null && ok "khoj — AI memory server" || { warn "khoj — NOT FOUND"; INSTALL_OK=false; }
"$PG_BIN/pg_isready" -q 2>/dev/null && ok "postgresql — database running" || { warn "postgresql — not running"; INSTALL_OK=false; }

# AI model
command -v ollama &>/dev/null && ok "ollama — local AI runtime" || { warn "ollama — NOT FOUND"; INSTALL_OK=false; }
ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL" && ok "$OLLAMA_MODEL — AI model ready" || { warn "$OLLAMA_MODEL — model not found (run: ollama pull $OLLAMA_MODEL)"; INSTALL_OK=false; }

# Memory capture tools
command -v sox &>/dev/null && ok "sox — audio recorder" || { warn "sox — NOT FOUND (voice notes won't work)"; INSTALL_OK=false; }
command -v whisper-cli &>/dev/null && ok "whisper-cpp — speech-to-text (whisper-cli)" || { warn "whisper-cpp — NOT FOUND (transcription won't work)"; INSTALL_OK=false; }
[[ -f "$WHISPER_MODEL" ]] && ok "whisper model — downloaded" || { warn "whisper model — NOT FOUND (transcription won't work)"; }
pgrep -q Hammerspoon && ok "hammerspoon — running (hotkeys active)" || { warn "hammerspoon — not running (start: open -a Hammerspoon)"; }

# Files and directories
[[ -d "$SYS_DIR/files/memories/assets" ]] && ok "memories directory — ready" || { warn "memories directory — missing"; INSTALL_OK=false; }
[[ -f "$SYS_DIR/config/khoj.env" ]] && ok "config file — ready" || { warn "config file — missing"; INSTALL_OK=false; }
[[ -x "$SYS_BIN" ]] && ok "launch command — $CMD_NAME" || { warn "launch command — NOT FOUND at $SYS_BIN"; INSTALL_OK=false; }

echo ""
if [[ "$INSTALL_OK" == true ]]; then
  echo "  ✓ All dependencies verified!"
else
  echo "  ⚠ Some dependencies had issues (see warnings above)."
  echo "    The system will still work — missing tools only affect specific features."
fi

# ── 21. Set access code ───────────────────────
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Almost done! Set your secret access code."
echo "  ──────────────────────────────────────────────────────────────"
echo ""
echo "  This 6-character code is required every time you start $CMD_NAME."
echo "  If someone types the wrong code, the program silently exits"
echo "  — it looks identical to a normal exit. No error, no hint."
echo ""
"$SYS_DIR/.sys/setgrove.sh"

# ── 22. Set admin credentials ────────────────
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  Set your admin credentials"
echo "  ──────────────────────────────────────────────────────────────"
echo ""
echo "  These are used to log in at http://localhost:9371/server/admin"
echo "  where you'll manage AI models and content sources."
echo ""
read -p "  Admin email: " ADMIN_EMAIL
read -s -p "  Admin password: " ADMIN_PASS
echo ""

sed -i '' "s|^KHOJ_ADMIN_EMAIL=.*|KHOJ_ADMIN_EMAIL=${ADMIN_EMAIL}|" "$SYS_DIR/config/khoj.env"
sed -i '' "s|^KHOJ_ADMIN_PASSWORD=.*|KHOJ_ADMIN_PASSWORD=${ADMIN_PASS}|" "$SYS_DIR/config/khoj.env"

# ── Done ─────────────────────────────────────
echo ""
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║                                                              ║"
echo "  ║   ✓  Setup complete! Here's how to get started.              ║"
echo "  ║                                                              ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  STEP 1  Start the server                                    │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    In your terminal, type:"
echo ""
echo "      $CMD_NAME"
echo ""
echo "    The cursor will blink with no prompt — type your 6-character"
echo "    access code (the characters won't appear on screen for"
echo "    security). Press Enter."
echo ""
echo "    The server will start. Open your browser to:"
echo ""
echo "      http://localhost:9371"
echo ""
echo "    To access from your iPhone (via Tailscale), start with:"
echo ""
echo "      $CMD_NAME --remote"
echo ""
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  STEP 2  Connect the AI model (one-time setup)               │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    The AI model ('$OLLAMA_MODEL') was already downloaded during"
echo "    installation. You just need to tell Khoj how to talk to it."
echo ""
echo "    Open the admin panel in your browser:"
echo ""
echo "      http://localhost:9371/server/admin"
echo ""
echo "    Log in with the email and password you set during install."
echo ""
echo "    FIRST — Create an API connection to Ollama:"
echo ""
echo "      1. In the left sidebar, click 'AI model APIs'"
echo "      2. Click 'Add AI model API' (top right)"
echo "      3. Fill in these fields:"
echo ""
echo "           Name:          Ollama"
echo "           API type:      Openai"
echo "           API base URL:  http://localhost:11434/v1/"
echo "           API key:       none"
echo ""
echo "      4. Click Save"
echo ""
echo "    THEN — Create a chat model that uses it:"
echo ""
echo "      5. In the left sidebar, click 'Chat model options'"
echo "      6. Click 'Add chat model option' (top right)"
echo "      7. Fill in these fields:"
echo ""
echo "           Name:          $OLLAMA_MODEL"
echo "           Model type:    Openai"
echo "           Chat model:    $OLLAMA_MODEL"
echo "           AI model API:  Ollama  (select the one you just made)"
echo ""
echo "      8. Click Save"
echo ""
echo "    Done! You can now chat with your AI at http://localhost:9371"
echo "    Everything runs on your machine — no data leaves it."
echo ""
echo "    Want to try a different model later? In your terminal:"
echo ""
echo "      ollama pull llama3.2       (smaller & faster, ~2 GB)"
echo "      ollama pull mixtral         (larger & smarter, ~26 GB)"
echo "      ollama list                 (see all your models)"
echo ""
echo "    Then add the new model in the admin panel the same way."
echo ""
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  STEP 3  Tell Khoj where your notes are                      │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    In the admin panel (http://localhost:9371/server/admin):"
echo ""
echo "      1. In the left sidebar, click 'Content source — filesystem'"
echo "         (or 'Directory' depending on your Khoj version)"
echo "      2. Click 'Add' (top right)"
echo "      3. Set the path to:"
echo ""
echo "           $HOME/.$SYS_NAME/files"
echo ""
echo "      4. Click Save"
echo ""
echo "    Khoj will now index all your notes and memories."
echo "    It re-indexes automatically whenever you add new captures."
echo ""
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  STEP 4  Capture memories — 3 ways, from anywhere            │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    These keyboard shortcuts work from ANY app on your Mac."
echo "    No terminal needed — just press the keys."
echo ""
echo "    ╔════════════════╦═══════════════════════════════════════════╗"
echo "    ║  Ctrl+Opt+T    ║  QUICK TEXT NOTE                         ║"
echo "    ║                ║  A dialog appears. Type your thought,    ║"
echo "    ║                ║  click Save.                             ║"
echo "    ╠════════════════╬═══════════════════════════════════════════╣"
echo "    ║  Ctrl+Opt+S    ║  SCREENSHOT                              ║"
echo "    ║                ║  Draw a box around any part of your      ║"
echo "    ║                ║  screen. Add a caption (optional).       ║"
echo "    ║                ║  Text in the image is auto-extracted.    ║"
echo "    ╠════════════════╬═══════════════════════════════════════════╣"
echo "    ║  Ctrl+Opt+A    ║  VOICE NOTE                              ║"
echo "    ║                ║  Press once to start recording.          ║"
echo "    ║                ║  Red bar + menu bar dot appear.          ║"
echo "    ║                ║  Press again (or click dot) to stop.     ║"
echo "    ║                ║  Audio is transcribed automatically.     ║"
echo "    ╠════════════════╬═══════════════════════════════════════════╣"
echo "    ║  Ctrl+Opt+L    ║  DEBUG LOG                               ║"
echo "    ║                ║  View recent capture activity and        ║"
echo "    ║                ║  errors. Useful for troubleshooting.     ║"
echo "    ╚════════════════╩═══════════════════════════════════════════╝"
echo ""
echo "    Everything is saved to: ~/.$SYS_NAME/files/memories/"
echo "    Khoj re-indexes automatically after each capture."
echo ""
echo "    You can also save memories from the terminal:"
echo ""
echo "      ~/.$SYS_NAME/.sys/capture-text.sh \"Meeting moved to 3pm\""
echo ""
echo "    Or drop any .md or .txt file directly into your notes folder:"
echo ""
echo "      cp my-notes.md ~/.$SYS_NAME/files/"
echo ""
echo ""
if [[ "$GDRIVE_INBOX" != "GDRIVE_NOT_CONFIGURED/$SYS_NAME" ]]; then
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  BONUS  Google Drive auto-import is active                   │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    Drop .md or .txt files into your Google Drive inbox folder:"
echo ""
echo "      $GDRIVE_INBOX"
echo ""
echo "    They'll be auto-copied into your notes and re-indexed."
echo ""
else
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  OPTIONAL  Google Drive auto-import                          │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    Google Drive Desktop was not detected during install."
echo "    To enable auto-import later:"
echo "      1. Install Google Drive: https://www.google.com/drive/download/"
echo "      2. Re-run this installer, or edit:"
echo "         ~/.$SYS_NAME/.sys/watcher.sh"
echo ""
fi
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  OPTIONAL  iPhone remote access                              │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    To access your memories from your phone:"
echo "      1. Install Tailscale on your Mac and iPhone (same account)"
echo "      2. Start the server with:  $CMD_NAME --remote"
echo "      3. On your iPhone, open Safari and go to:"
echo "         http://[your-mac-tailscale-ip]:9371"
echo ""
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  TROUBLESHOOTING                                             │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "    Hotkeys not working?"
echo "      → Make sure you've granted permissions (see the permission"
echo "        guide shown during install, or check System Settings →"
echo "        Privacy & Security → Accessibility, Screen Recording,"
echo "        and Microphone for Hammerspoon)."
echo "      → Restart Hammerspoon:  open -a Hammerspoon"
echo ""
echo "    Forgot your access code?"
echo "      → Set a new one:  ~/.$SYS_NAME/.sys/setgrove.sh"
echo ""
echo "    Server won't start?"
echo "      → Make sure PostgreSQL is running:  brew services start postgresql@${PG_VERSION}"
echo "      → Make sure Ollama is running:  open -a Ollama"
echo ""
echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Quick Reference Card"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "    Start server        $CMD_NAME"
echo "    Admin panel         http://localhost:9371/server/admin"
echo "    Quick text          Ctrl + Opt + T"
echo "    Screenshot          Ctrl + Opt + S"
echo "    Voice note          Ctrl + Opt + A"
echo "    Debug log           Ctrl + Opt + L"
echo "    Re-index notes      ~/.$SYS_NAME/.sys/reindex.sh"
echo "    Change access code  ~/.$SYS_NAME/.sys/setgrove.sh"
echo "    Data folder         ~/.$SYS_NAME/"
echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
