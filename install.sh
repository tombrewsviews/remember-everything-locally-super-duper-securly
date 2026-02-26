#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
#  logmem — local AI memory system
#  installer for macOS
# ─────────────────────────────────────────────

LOGMEM_DIR="$HOME/.logmem"
LOGMEM_BIN="$HOME/.local/bin/logmem"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  logmem installer"
echo "  ────────────────"
echo ""

# ── 1. Check macOS ──────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: logmem requires macOS."
  exit 1
fi

# ── 2. Check Homebrew ───────────────────────
if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew is required. Install it from https://brew.sh"
  exit 1
fi

# ── 3. Check Python 3.10–3.12 ───────────────
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

# ── 4. Install brew dependencies ────────────
echo "Installing brew dependencies..."
brew install pipx fswatch 2>/dev/null || true
brew install --cask tailscale 2>/dev/null || true
pipx ensurepath

# ── 5. Install Khoj ─────────────────────────
if ! command -v khoj &>/dev/null; then
  echo "Installing Khoj..."
  pipx install khoj --python "$PYTHON_BIN"
else
  echo "Khoj already installed: $(command -v khoj)"
fi

# ── 6. Install PostgreSQL + pgvector ────────
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

# Install pgvector and link to installed PostgreSQL
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

# Start PostgreSQL
brew services start postgresql@${PG_VERSION} 2>/dev/null || true
sleep 3

# Create khoj database
"$PG_BIN/createdb" -U "$(whoami)" khoj 2>/dev/null || echo "khoj database already exists"

# ── 7. Create directory structure ───────────
echo "Creating ~/.logmem directory structure..."
mkdir -p "$LOGMEM_DIR/files"
mkdir -p "$LOGMEM_DIR/.sys"
mkdir -p "$LOGMEM_DIR/config"
touch "$LOGMEM_DIR/.sys/import.log"
echo "*" > "$LOGMEM_DIR/.gitignore"
touch "$LOGMEM_DIR/.metadata_never_index"
touch "$LOGMEM_DIR/files/.metadata_never_index"

# ── 8. Copy scripts ──────────────────────────
cp "$SCRIPT_DIR/scripts/setgrove.sh"  "$LOGMEM_DIR/.sys/setgrove.sh"
cp "$SCRIPT_DIR/scripts/reindex.sh"   "$LOGMEM_DIR/.sys/reindex.sh"
chmod +x "$LOGMEM_DIR/.sys/setgrove.sh"
chmod +x "$LOGMEM_DIR/.sys/reindex.sh"

# ── 9. Detect Google Drive ───────────────────
GDRIVE_INBOX="GDRIVE_NOT_CONFIGURED/LogMem"
GDRIVE_PATH=$(find ~/Library/CloudStorage -maxdepth 2 -name "My Drive" -type d 2>/dev/null | grep -i "gmail\|google" | head -1)
if [[ -n "$GDRIVE_PATH" ]]; then
  mkdir -p "$GDRIVE_PATH/LogMem"
  GDRIVE_INBOX="$GDRIVE_PATH/LogMem"
  echo "Google Drive found: $GDRIVE_INBOX"
else
  echo ""
  echo "  ⚠️  Google Drive Desktop not found."
  echo "     Install it from https://www.google.com/drive/download/"
  echo "     Then edit GDRIVE_INBOX in ~/.logmem/.sys/watcher.sh"
  echo ""
fi

# Write watcher with detected path
sed "s|GDRIVE_NOT_CONFIGURED/LogMem|$GDRIVE_INBOX|g" \
  "$SCRIPT_DIR/scripts/watcher.sh" > "$LOGMEM_DIR/.sys/watcher.sh"
chmod +x "$LOGMEM_DIR/.sys/watcher.sh"

# ── 10. Generate config ──────────────────────
SECRET_KEY=$("$PYTHON_BIN" -c "import secrets; print(secrets.token_urlsafe(50))")
DB_USER="$(whoami)"

cat > "$LOGMEM_DIR/config/khoj.env" << EOF
# Khoj runtime config — do not share or commit this file
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
chmod 600 "$LOGMEM_DIR/config/khoj.env"

# ── 11. Install logmem command ───────────────
mkdir -p "$HOME/.local/bin"
sed "s|postgresql@16|postgresql@${PG_VERSION}|g; s|postgresql@17|postgresql@${PG_VERSION}|g" \
  "$SCRIPT_DIR/scripts/logmem.sh" > "$LOGMEM_BIN"
chmod +x "$LOGMEM_BIN"

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
fi

# ── 12. Install LaunchAgent ──────────────────
PLIST="$HOME/Library/LaunchAgents/com.user.logmem-watch.plist"
sed "s|REPLACE_HOME|$HOME|g" "$SCRIPT_DIR/templates/launchagent.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
launchctl start com.user.logmem-watch 2>/dev/null || true

# ── 13. Set GROVE_CODE ───────────────────────
echo ""
echo "  Almost done! You need to set your access code."
echo "  This is a 6-character code required to start logmem."
echo ""
"$LOGMEM_DIR/.sys/setgrove.sh"

# ── 14. Set admin credentials ───────────────
echo ""
echo "  Set your Khoj admin credentials (used to log in at /server/admin):"
echo ""
read -p "  Admin email: " ADMIN_EMAIL
read -s -p "  Admin password: " ADMIN_PASS
echo ""

sed -i '' "s|^KHOJ_ADMIN_EMAIL=.*|KHOJ_ADMIN_EMAIL=${ADMIN_EMAIL}|" "$LOGMEM_DIR/config/khoj.env"
sed -i '' "s|^KHOJ_ADMIN_PASSWORD=.*|KHOJ_ADMIN_PASSWORD=${ADMIN_PASS}|" "$LOGMEM_DIR/config/khoj.env"

# ── Done ─────────────────────────────────────
echo ""
echo "  ✓ logmem installed successfully"
echo ""
echo "  Commands:"
echo "    logmem           — start (localhost only)"
echo "    logmem --remote  — start (accessible via Tailscale from iPhone)"
echo ""
echo "  Next steps:"
echo "    1. Run: logmem"
echo "    2. Open: http://localhost:9371/server/admin"
echo "    3. Go to Chat models → add your AI model (Ollama or API key)"
echo "    4. Add ~/.logmem/files as a content source"
echo ""
if [[ "$GDRIVE_INBOX" == "GDRIVE_NOT_CONFIGURED/LogMem" ]]; then
  echo "    5. Install Google Drive Desktop, then edit GDRIVE_INBOX in:"
  echo "       ~/.logmem/.sys/watcher.sh"
  echo ""
fi
