#!/usr/bin/env bash
# Removes what install-app.sh installed. Your documents and settings are not touched.
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

rm -rf  "$DATA/ChaoticNotepad"
rm -f   "$HOME/.local/bin/ChaoticNotepad"
rm -f   "$DATA/applications/ChaoticNotepad.desktop"
rm -f   "$DATA/icons/hicolor/scalable/apps/ChaoticNotepad.svg"

if command -v update-desktop-database > /dev/null 2>&1; then
  update-desktop-database "$DATA/applications" > /dev/null 2>&1 || true
fi

echo "ChaoticNotepad has been removed."
