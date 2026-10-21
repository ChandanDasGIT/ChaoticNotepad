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
export EXTRA_PLATFORM_PLUGINS="libqwayland-generic.so;libqwayland-egl.so"   # also bundle Wayland, not just xcb
export EXTRA_QT_PLUGINS="waylandcompositor"
export EXTRA_QT_MODULES="waylandcompositor"

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

# Deploy Qt and its dependencies into AppDir (no AppImage yet)
linuxdeploy-x86_64.AppImage \
  --appdir AppDir \
  --plugin qt \
  --desktop-file ChaoticNotepad.desktop \
  --icon-file ChaoticNotepad.svg

QT_PLUGIN_DIR="$("$QMAKE" -query QT_INSTALL_PLUGINS)"
QT_LIB_DIR="$("$QMAKE" -query QT_INSTALL_LIBS)"

# Show what exists and what got bundled, so the CI log explains any failure below
echo "== Qt plugins available in $QT_PLUGIN_DIR"
ls "$QT_PLUGIN_DIR" "$QT_PLUGIN_DIR/platforms"
echo "== Plugins bundled so far"
ls AppDir/usr/plugins AppDir/usr/plugins/platforms

# Copy any Wayland plugin linuxdeploy skipped, straight from the Qt install
mkdir -p AppDir/usr/plugins/platforms AppDir/usr/lib
for p in libqwayland-generic.so libqwayland-egl.so; do
  if [ ! -f "AppDir/usr/plugins/platforms/$p" ] && [ -f "$QT_PLUGIN_DIR/platforms/$p" ]; then
    cp -L "$QT_PLUGIN_DIR/platforms/$p" AppDir/usr/plugins/platforms/
  fi
done
for d in wayland-decoration-client wayland-graphics-integration-client wayland-graphic-integration-client wayland-shell-integration; do
  if [ ! -d "AppDir/usr/plugins/$d" ] && [ -d "$QT_PLUGIN_DIR/$d" ]; then
    cp -a "$QT_PLUGIN_DIR/$d" AppDir/usr/plugins/
  fi
done
for lib in libQt6WaylandClient.so.6 libQt6WaylandEglClientHwIntegration.so.6 libQt6WlShellIntegration.so.6; do
  if [ ! -e "AppDir/usr/lib/$lib" ] && [ -e "$QT_LIB_DIR/$lib" ]; then
    cp -L "$QT_LIB_DIR/$lib" AppDir/usr/lib/
  fi
done

# Make the Wayland plugins and libs find the bundled libraries at runtime
for so in AppDir/usr/plugins/platforms/libqwayland-*.so AppDir/usr/plugins/wayland-*/*.so; do
  if [ -f "$so" ]; then patchelf --set-rpath '$ORIGIN/../../lib' "$so"; fi
done
for so in AppDir/usr/lib/libQt6Wayland*.so.6 AppDir/usr/lib/libQt6WlShellIntegration.so.6; do
  if [ -f "$so" ]; then patchelf --set-rpath '$ORIGIN' "$so"; fi
done

# Print any library the Wayland plugins still can't find (informational)
for so in AppDir/usr/plugins/platforms/libqwayland-*.so AppDir/usr/plugins/wayland-*/*.so; do
  if [ -f "$so" ]; then
    echo "== missing libs for $so:"
    LD_LIBRARY_PATH="$ROOT/AppDir/usr/lib:$QT_LIB_DIR" ldd "$so" | grep 'not found' || true
  fi
done

# Fail the build if the Wayland pieces are missing, so a broken release can't ship
[ -f AppDir/usr/plugins/platforms/libqwayland-generic.so ] || { echo "Wayland platform plugin was not bundled" >&2; exit 1; }
[ -d AppDir/usr/plugins/wayland-shell-integration ] || { echo "wayland-shell-integration was not bundled" >&2; exit 1; }
ls -d AppDir/usr/plugins/wayland-graphic*-integration-client >/dev/null 2>&1 || { echo "wayland graphics integration plugin was not bundled" >&2; exit 1; }

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
