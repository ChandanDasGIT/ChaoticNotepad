# ChaoticNotepad

A modern, minimalist cross-platform text and code editor built with C++ and Qt6 QML.

## Installation

### Install from Pre-Compiled Release (Recommended)

1. Download `ChaoticNotepad-v1.0-linux-x86_64.tar.xz` from the **Releases** page.
2. Extract the archive and run the binary installer:

```bash
tar -xf ChaoticNotepad-v1.0-linux-x86_64.tar.xz
cd ChaoticNotepad-linux-x86_64
chmod +x install-app.sh
sudo ./install-app.sh
```

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
