#!/usr/bin/env bash
# Installs ChaoticNotepad for the current user. No root needed.
# Run it from the unpacked folder:  ./install-app.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -x "$HERE/app/AppRun" ]; then
  echo "The 'app' folder is missing. Run this script from the unpacked ChaoticNotepad folder." >&2
  exit 1
fi

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA/ChaoticNotepad"
BIN_DIR="$HOME/.local/bin"
MENU_DIR="$DATA/applications"
ICON_DIR="$DATA/icons/hicolor/scalable/apps"

mkdir -p "$BIN_DIR" "$MENU_DIR" "$ICON_DIR"

# the program
rm -rf "$APP_DIR"
cp -a "$HERE/app" "$APP_DIR"

# the "ChaoticNotepad" command
ln -sf "$APP_DIR/AppRun" "$BIN_DIR/ChaoticNotepad"

# the icon
cp "$APP_DIR/usr/share/icons/hicolor/scalable/apps/ChaoticNotepad.svg" "$ICON_DIR/ChaoticNotepad.svg"

# the menu entry (the shipped one, pointing at the installed copy)
SRC="$APP_DIR/usr/share/applications/ChaoticNotepad.desktop"
if [ -f "$SRC" ]; then
  sed -e "s|^Exec=.*|Exec=\"$APP_DIR/AppRun\" %F|" \
      -e "s|^Icon=.*|Icon=ChaoticNotepad|" \
      "$SRC" > "$MENU_DIR/ChaoticNotepad.desktop"
else
  cat > "$MENU_DIR/ChaoticNotepad.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ChaoticNotepad
Exec="$APP_DIR/AppRun" %F
Icon=ChaoticNotepad
Categories=Utility;TextEditor;
Terminal=false
EOF
fi

if command -v update-desktop-database > /dev/null 2>&1; then
  update-desktop-database "$MENU_DIR" > /dev/null 2>&1 || true
fi

echo "ChaoticNotepad is installed."
echo "  Program : $APP_DIR"
echo "  Command : $BIN_DIR/ChaoticNotepad"
echo "  Menu    : $MENU_DIR/ChaoticNotepad.desktop"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Note: $BIN_DIR is not on your PATH, so the 'ChaoticNotepad' command will not work until you add it." ;;
esac
