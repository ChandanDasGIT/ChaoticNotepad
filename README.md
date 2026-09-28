## Installation

### Prerequisites
Make sure you have CMake, a C++20 compiler, and Qt 6 development packages installed:

- **Fedora:** `sudo dnf install cmake gcc-c++ qt6-qtdeclarative-devel qt6-qtquickcontrols2-devel`
- **Arch Linux:** `sudo pacman -S cmake gcc qt6-declarative qt6-quickcontrols2`
- **Ubuntu/Debian:** `sudo apt install cmake g++ qt6-declarative-dev qml6-module-qtquick-controls`

### Install from Release Archive

1. Download `ChaoticNotepad-v0.1-source.tar.xz` from the **Releases** page.
2. Extract and run the installer:

`
  tar -xf ChaoticNotepad-v0.1-source.tar.xz
  cd ChaoticNotepad-v0.1-source
  sudo ./install.sh
`
-or, use git clone:

`
git clone https://github.com/ChandanDasGIT/ChaoticNotepad.git
cd ChaoticNotepad
sudo ./install.sh
`

-To uninstall :
`sudo ./uninstall`
