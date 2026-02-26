#!/usr/bin/env bash

GRVMAP="$HOME/.logmem/.sys/.grvmap"
LOGMEM_PORT=9371

# Check that the access code has been set
if [ ! -f "$GRVMAP" ]; then
  echo "Not configured. Run: ~/.logmem/.sys/setgrove.sh"
  exit 1
fi

# Prompt silently — no text, no hint
read -s -p "" INPUT_CODE
HASHED=$(echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}')
STORED=$(cat "$GRVMAP")

if [ "$HASHED" != "$STORED" ]; then
  # Silent failure — wrong code looks identical to normal exit
  exit 0
fi

# Load environment
if [ -f "$HOME/.logmem/config/khoj.env" ]; then
  set -a
  source "$HOME/.logmem/config/khoj.env"
  set +a
fi

# Ensure PostgreSQL is in PATH
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# --remote flag binds to all interfaces (for Tailscale access from iPhone)
BIND_HOST="127.0.0.1"
if [[ "$1" == "--remote" ]]; then
  BIND_HOST="0.0.0.0"
fi

exec khoj \
  --host "$BIND_HOST" \
  --port "$LOGMEM_PORT" \
  --anonymous-mode \
  2>&1
