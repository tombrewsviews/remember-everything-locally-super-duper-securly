#!/usr/bin/env bash
# Set or change the 6-character access code for remember-everything-locally-super-duper-securly.
# Run this once during setup, or again any time you want to change it.
# Template — SYSTEM_NAME is replaced by install.sh.

GRVMAP="$HOME/.SYSTEM_NAME/.sys/.grvmap"

echo ""
read -s -p "Enter new 6-character access code: " INPUT_CODE
echo ""
read -s -p "Confirm access code: " CONFIRM_CODE
echo ""

if [ "$INPUT_CODE" != "$CONFIRM_CODE" ]; then
  echo "Codes do not match. Aborted."
  exit 1
fi

if [ "${#INPUT_CODE}" -ne 6 ]; then
  echo "Code must be exactly 6 characters."
  exit 1
fi

HASHED=$(echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}')
echo "$HASHED" > "$GRVMAP"
chmod 600 "$GRVMAP"

echo "Access code set successfully."
