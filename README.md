# ChaoticNotepad

A modern, minimalist cross-platform text and code editor built with C++ and Qt6 QML.

## Features

- **Tabbed Interface:** Manage multiple open documents seamlessly.
- **Syntax Highlighting:** Clean highlighting for C++ and various text formats.
- **Minimap:** Quick document overview and navigation.
- **Find & Replace:** Fast regex-enabled text searching.
- **Custom Palette:** Polished custom UI styling.

---

## Installation

### Install from Pre-Compiled Release (Recommended)

1. Download `.tar.xz` file from the **Releases** page.
2. Extract the archive, go to the extracted folder(in the tarminal) and simply run :

```bash
 ./install-app.sh
```
3. To uninstall, go to the extracted folder(in the tarminal) and simply run :

```bash
 ./uninstall-app.sh
```

### Install from Pre-Compiled Release (Recommended)

1. Download `ChaoticNotepad-1.0-x86_64.AppImage` from the **Releases** page.
2. run the AppImage

### Build and Install from Source (Alternative)

If you prefer to clone the repository and build natively from source:

1. Ensure you have the prerequisites installed:
  - Fedora: `sudo dnf install cmake gcc-c++ qt6-qtdeclarative-devel qt6-qtquickcontrols2-devel`
  - Arch Linux: `sudo pacman -S cmake gcc qt6-declarative qt6-quickcontrols2`
  - Ubuntu/Debian: `sudo apt install cmake g++ qt6-declarative-dev qml6-module-qtquick-controls`

2. Clone and build:

```bash
git clone https://github.com/ChandanDasGIT/ChaoticNotepad.git
cd ChaoticNotepad
sudo ./install.sh
```

## Uninstallation

If installed via the pre-compiled binary package:

```bash
sudo ./uninstall-app.sh
```

If installed from source:

```bash
sudo ./uninstall.sh
