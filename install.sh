#!/usr/bin/env bash
set -e

# Require root permissions for system-wide install
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./install.sh)"
  exit 1
fi

BUILD_DIR="build"

# Configure if build directory doesn't exist
if [ ! -d "$BUILD_DIR" ]; then
  cmake -B "$BUILD_DIR" -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
fi

# Build and Install
cmake --build "$BUILD_DIR" --parallel
cmake --install "$BUILD_DIR"

# Update Linux desktop and icon caches
if command -v update-desktop-database &> /dev/null; then
  update-desktop-database /usr/local/share/applications 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
  gtk-update-icon-cache -f -t /usr/local/share/icons/hicolor 2>/dev/null || true
fi

# A copy from the release tarball (install-app.sh) lives in the user's home and would open instead of this one.
# Only that copy goes: the settings stay. Under sudo, SUDO_USER tells whose home it is.
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  USER_DATA="$USER_HOME/.local/share"
  if [ -n "$USER_HOME" ] && [ -x "$USER_DATA/ChaoticNotepad/AppRun" ]; then
    rm -rf "$USER_DATA/ChaoticNotepad"
    if [ -L "$USER_HOME/.local/bin/ChaoticNotepad" ]; then rm -f "$USER_HOME/.local/bin/ChaoticNotepad"; fi
    rm -f "$USER_DATA/applications/ChaoticNotepad.desktop"
    rm -f "$USER_DATA/icons/hicolor/scalable/apps/ChaoticNotepad.svg"
    if command -v update-desktop-database &> /dev/null; then
      sudo -u "$SUDO_USER" update-desktop-database "$USER_DATA/applications" 2>/dev/null || true
    fi
    echo "Removed the copy installed from the release tarball, so this version is the one that opens."
  fi
fi

echo "ChaoticNotepad installed successfully!"
