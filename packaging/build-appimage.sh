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
export EXTRA_QT_MODULES="waylandcompositor"   # older name of the same setting, harmless if ignored

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
DESKTOP_DESTDIR="$ROOT/AppDir"
DESTDIR="$DESKTOP_DESTDIR" cmake --install build-release

# Deploy Qt and its dependencies into AppDir (no AppImage yet)
linuxdeploy-x86_64.AppImage \
  --appdir AppDir \
  --plugin qt \
  --desktop-file ChaoticNotepad.desktop \
  --icon-file ChaoticNotepad.svg

# linuxdeploy's Qt plugin skips the Qt 6 name of the Wayland OpenGL plugin folder, so copy it by hand
QT_PLUGIN_DIR="$("$QMAKE" -query QT_INSTALL_PLUGINS)"
QT_LIB_DIR="$("$QMAKE" -query QT_INSTALL_LIBS)"
found=""
for d in wayland-graphics-integration-client wayland-graphic-integration-client; do
  if [ -d "$QT_PLUGIN_DIR/$d" ]; then
    mkdir -p AppDir/usr/plugins
    cp -a "$QT_PLUGIN_DIR/$d" AppDir/usr/plugins/
    found="$d"
  fi
done
[ -n "$found" ] || { echo "No wayland graphics integration plugin found in $QT_PLUGIN_DIR:" >&2; ls "$QT_PLUGIN_DIR" >&2; exit 1; }
cp -a "$QT_LIB_DIR"/libQt6WaylandEglClientHwIntegration.so* AppDir/usr/lib/ \
  || { echo "libQt6WaylandEglClientHwIntegration not found in $QT_LIB_DIR" >&2; exit 1; }

# Fail the build if the Wayland pieces are missing, so a broken release can't ship
[ -f AppDir/usr/plugins/platforms/libqwayland-generic.so ] || { echo "Wayland platform plugin was not bundled" >&2; exit 1; }
[ -d AppDir/usr/plugins/wayland-shell-integration ] || { echo "wayland-shell-integration was not bundled" >&2; exit 1; }
[ -d AppDir/usr/plugins/wayland-graphics-integration-client ] || { echo "wayland-graphics-integration-client was not bundled" >&2; exit 1; }

# Now pack the AppImage
linuxdeploy-x86_64.AppImage --appdir AppDir --output appimage

APPIMAGE="dist/ChaoticNotepad-${VERSION}-x86_64.AppImage"
mv ChaoticNotepad*.AppImage "$APPIMAGE"

# Bundled tarball: unpack the finished AppImage, add the installer, compress
( cd dist
  "../$APPIMAGE" --appimage-extract >/dev/null
  DIRNAME="ChaoticNotepad-${VERSION}-linux-x86_64"
  mv squashfs-root "$DIRNAME"
  cp "$ROOT/packaging/install-app.sh" "$ROOT/packaging/uninstall-app.sh" "$DIRNAME/"
  chmod +x "$DIRNAME/install-app.sh" "$DIRNAME/uninstall-app.sh"
  tar -cJf "$DIRNAME.tar.xz" "$DIRNAME"
  rm -rf "$DIRNAME"
  sha256sum * > SHA256SUMS.txt )

ls -lh dist
