#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: $0 <version, e.g. 1.0>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export ARCH=x86_64
export VERSION
export APPIMAGE_EXTRACT_AND_RUN=1      # lets linuxdeploy run without FUSE
export NO_STRIP=1                      # linuxdeploy's old strip can't read newer Fedora libraries
export QML_SOURCES_PATHS="$ROOT"       # bundle every QML module your .qml files import

# linuxdeploy's Qt plugin needs to know where qmake is (distros name it differently)
if [ -z "${QMAKE:-}" ]; then
  for q in qmake6 qmake-qt6 qmake; do
    if command -v "$q" >/dev/null 2>&1; then export QMAKE="$(command -v "$q")"; break; fi
  done
fi
[ -n "${QMAKE:-}" ] || { echo "qmake not found. Install the Qt 6 development packages." >&2; exit 1; }

# Start clean every time
rm -rf dist AppDir build-release
mkdir -p tools dist
export PATH="$ROOT/tools:$PATH"

# Download the packaging tools (only once)
for f in linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
         linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage; do
  out="tools/$(basename "$f")"
  [ -f "$out" ] || wget -q -O "$out" "https://github.com/$f"
  chmod +x "$out"
done

# Build
cmake -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build-release

# Stage into AppDir
DESTDIR="$ROOT/AppDir" cmake --install build-release

# Create the AppImage
linuxdeploy-x86_64.AppImage \
  --appdir AppDir \
  --plugin qt \
  --desktop-file ChaoticNotepad.desktop \
  --icon-file ChaoticNotepad.svg \
  --output appimage

APPIMAGE="dist/ChaoticNotepad-${VERSION}-x86_64.AppImage"
mv ChaoticNotepad*.AppImage "$APPIMAGE"

# Bundled tarball: unpack the finished AppImage, add the installer, compress
( cd dist
  "../$APPIMAGE" --appimage-extract >/dev/null
  DIRNAME="ChaoticNotepad-${VERSION}-linux-x86_64"
  mv squashfs-root "$DIRNAME"
  cp "$ROOT/packaging/install-app.sh" "$DIRNAME/install-app.sh"
  chmod +x "$DIRNAME/install-app.sh"
  tar -cJf "$DIRNAME.tar.xz" "$DIRNAME"
  rm -rf "$DIRNAME"
  sha256sum * > SHA256SUMS.txt )

ls -lh dist
