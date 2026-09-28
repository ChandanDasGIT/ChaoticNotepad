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

echo "ChaoticNotepad installed successfully!"
