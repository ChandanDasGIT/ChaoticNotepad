#!/usr/bin/env bash
set -e

# Require root permissions
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./uninstall.sh)"
  exit 1
fi

echo "Uninstalling ChaoticNotepad..."

# Remove installed binary and desktop integration files
rm -f /usr/local/bin/ChaoticNotepad
rm -f /usr/local/share/applications/ChaoticNotepad.desktop
rm -f /usr/local/share/icons/hicolor/256x256/apps/ChaoticNotepad.png

# Update desktop and icon databases
if command -v update-desktop-database &> /dev/null; then
  update-desktop-database /usr/local/share/applications 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
  gtk-update-icon-cache -f -t /usr/local/share/icons/hicolor 2>/dev/null || true
fi

echo "ChaoticNotepad uninstalled successfully."
