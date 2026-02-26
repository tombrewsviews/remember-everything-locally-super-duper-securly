#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
#  remember-everything-locally-super-duper-securly — local AI memory system
#  installer for macOS
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  remember-everything-locally-super-duper-securly installer"
echo "  ──────────────────────────────────────────────────────────"
echo ""

# ── 1. Check macOS ──────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: remember-everything-locally-super-duper-securly requires macOS."
  exit 1
fi

# ── 2. Check Homebrew ───────────────────────
if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew is required. Install it from https://brew.sh"
  exit 1
fi

# ── 3. Gather user preferences ──────────────
echo "  Let's personalise your setup."
echo ""

while true; do
  read -p "  System name (e.g. vault, brain, echo) — becomes ~/.name/: " SYS_NAME
  SYS_NAME="${SYS_NAME// /}"   # strip spaces
  SYS_NAME="${SYS_NAME,,}"     # lowercase
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
  CMD_NAME="${CMD_NAME,,}"
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

# ── 4. Check Python 3.10–3.12 ───────────────
PYTHON_BIN=""
for v in python3.12 python3.11 python3.10; do
  if command -v $v &>/dev/null; then
    PYTHON_BIN=$(command -v $v)
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  echo "Python 3.10–3.12 not found. Installing python@3.11..."
  brew install python@3.11
  PYTHON_BIN=$(command -v python3.11)
fi
echo "Using Python: $PYTHON_BIN ($($PYTHON_BIN --version))"

# ── 5. Install brew dependencies ────────────
echo "Installing brew dependencies..."
brew install pipx fswatch 2>/dev/null || true
brew install --cask tailscale 2>/dev/null || true
pipx ensurepath

# ── 6. Install Khoj ─────────────────────────
if ! command -v khoj &>/dev/null; then
  echo "Installing Khoj..."
  pipx install khoj --python "$PYTHON_BIN"
else
  echo "Khoj already installed: $(command -v khoj)"
fi

# ── 7. Install PostgreSQL + pgvector ────────
PG_VERSION=""
for v in 17 16; do
  if brew list postgresql@$v &>/dev/null 2>&1; then
    PG_VERSION=$v
    break
  fi
done
if [[ -z "$PG_VERSION" ]]; then
  echo "Installing PostgreSQL 17..."
  brew install postgresql@17
  PG_VERSION=17
fi
PG_BIN="/opt/homebrew/opt/postgresql@${PG_VERSION}/bin"
export PATH="$PG_BIN:$PATH"

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
  echo "pgvector linked to PostgreSQL $PG_VERSION"
else
  echo "WARNING: Could not link pgvector. You may need to do this manually."
fi

brew services start postgresql@${PG_VERSION} 2>/dev/null || true
sleep 3

"$PG_BIN/createdb" -U "$(whoami)" khoj 2>/dev/null || echo "khoj database already exists"

# ── 8. Create directory structure ───────────
echo "Creating ~/.$SYS_NAME/ directory structure..."
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
  echo "Google Drive found: $GDRIVE_INBOX"
else
  echo ""
  echo "  ⚠️  Google Drive Desktop not found."
  echo "     Install it from https://www.google.com/drive/download/"
  echo "     Then edit GDRIVE_INBOX in ~/.$SYS_NAME/.sys/watcher.sh"
  echo ""
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

# ── 14. Set access code ───────────────────────
echo ""
echo "  Almost done! You need to set your access code."
echo "  This is a 6-character code required to start $CMD_NAME."
echo ""
"$SYS_DIR/.sys/setgrove.sh"

# ── 15. Set admin credentials ────────────────
echo ""
echo "  Set your admin credentials (used to log in at /server/admin):"
echo ""
read -p "  Admin email: " ADMIN_EMAIL
read -s -p "  Admin password: " ADMIN_PASS
echo ""

sed -i '' "s|^KHOJ_ADMIN_EMAIL=.*|KHOJ_ADMIN_EMAIL=${ADMIN_EMAIL}|" "$SYS_DIR/config/khoj.env"
sed -i '' "s|^KHOJ_ADMIN_PASSWORD=.*|KHOJ_ADMIN_PASSWORD=${ADMIN_PASS}|" "$SYS_DIR/config/khoj.env"

# ── Done ─────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup complete."
echo ""
echo "  Start:         $CMD_NAME"
echo "  Remote start:  $CMD_NAME --remote"
echo "  Open:          http://localhost:9371"
echo "  Change code:   ~/.$SYS_NAME/.sys/setgrove.sh"
echo ""
echo "  Drop notes into: ~/.$SYS_NAME/files/"
echo "  Or via Google Drive inbox folder (auto-imported)"
echo ""
echo "  iPhone access: start with --remote, connect Tailscale,"
echo "  open http://[your-tailscale-ip]:9371 in Safari"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Next steps:"
echo "    1. Run: $CMD_NAME"
echo "    2. Open: http://localhost:9371/server/admin"
echo "    3. Go to Chat models → add your AI model (Ollama or API key)"
echo "    4. Add ~/.$SYS_NAME/files as a content source"
echo ""
if [[ "$GDRIVE_INBOX" == "GDRIVE_NOT_CONFIGURED/$SYS_NAME" ]]; then
  echo "    5. Install Google Drive Desktop, then edit GDRIVE_INBOX in:"
  echo "       ~/.$SYS_NAME/.sys/watcher.sh"
  echo ""
fi
