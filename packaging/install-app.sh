#!/usr/bin/env bash
# Installs ChaoticNotepad so it shows up in rofi, app menus, etc.
#   ./install-app.sh               install for the current user (no root needed)
#   sudo ./install-app.sh --system install for all users
#   ./install-app.sh --uninstall   remove (add --system if you installed that way)
set -euo pipefail

APP_NAME="ChaoticNotepad"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=install
SCOPE=user
for arg in "$@"; do
  case "$arg" in
    --system)    SCOPE=system ;;
    --uninstall) MODE=uninstall ;;
    -h|--help)   sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

if [ "$SCOPE" = system ]; then
  [ "$(id -u)" -eq 0 ] || { echo "--system needs root: sudo $0 --system" >&2; exit 1; }
  APP_DIR="/opt/$APP_NAME"
  BIN_DIR="/usr/local/bin"
  DATA_DIR="/usr/local/share"
else
  DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
  APP_DIR="$DATA_DIR/$APP_NAME"
  BIN_DIR="$HOME/.local/bin"
fi

DESKTOP_FILE="$DATA_DIR/applications/$APP_NAME.desktop"
ICON_FILE="$DATA_DIR/icons/hicolor/scalable/apps/$APP_NAME.svg"
LAUNCHER="$BIN_DIR/$APP_NAME"

refresh_caches() {
  # desktop entry database
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DATA_DIR/applications" 2>/dev/null || true
  fi
  # icon cache
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f "$DATA_DIR/icons/hicolor" 2>/dev/null || true
  fi
  # KDE menu cache
  for k in kbuildsycoca6 kbuildsycoca5; do
    command -v "$k" >/dev/null 2>&1 && { "$k" >/dev/null 2>&1 || true; break; }
  done
  # rofi keeps its own cache of the app list; deleting it forces a rescan
  if [ "$SCOPE" = user ]; then
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/rofi*.druncache 2>/dev/null || true
  fi
}

if [ "$MODE" = uninstall ]; then
  rm -rf "$APP_DIR"
  rm -f "$DESKTOP_FILE" "$ICON_FILE" "$LAUNCHER"
  refresh_caches
  echo "$APP_NAME removed."
  exit 0
fi

# --- install ---
[ -x "$SRC/AppRun" ] || { echo "AppRun not found next to this script. Run it from the extracted folder." >&2; exit 1; }

mkdir -p "$APP_DIR" "$BIN_DIR" "$DATA_DIR/applications" "$(dirname "$ICON_FILE")"

# copy the app (skip if running from the install location already)
if [ "$SRC" != "$APP_DIR" ]; then
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"
  cp -a "$SRC"/. "$APP_DIR"/
fi

# command-line launcher
cat > "$LAUNCHER" <<EOF
#!/bin/sh
exec "$APP_DIR/AppRun" "\$@"
EOF
chmod +x "$LAUNCHER"

# icon
for candidate in "$SRC/$APP_NAME.svg" "$SRC/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg"; do
  if [ -f "$candidate" ]; then cp "$candidate" "$ICON_FILE"; break; fi
done

# desktop entry
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=A code-focused notepad
Exec="$APP_DIR/AppRun" %F
Icon=$APP_NAME
Terminal=false
Categories=Utility;TextEditor;
MimeType=text/plain;
EOF
chmod 644 "$DESKTOP_FILE"

refresh_caches

# --- verify ---
if [ -f "$DESKTOP_FILE" ] && [ -x "$APP_DIR/AppRun" ]; then
  echo "✔ $APP_NAME installed."
  echo "  App files:     $APP_DIR"
  echo "  Menu entry:    $DESKTOP_FILE"
  echo "  Launch it from rofi / your app menu, or run: $APP_NAME"
else
  echo "✘ Something went wrong: the menu entry or app files are missing." >&2
  ls -l "$DESKTOP_FILE" "$APP_DIR/AppRun" >&2 || true
  exit 1
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "  Note: $BIN_DIR is not in your PATH, so the '$APP_NAME' command won't work until you add it." ;;
esac
echo "  To uninstall:  $APP_DIR/uninstall-app.sh$([ "$SCOPE" = system ] && echo ' --system')"
