# ChaoticNotepad

A modern, minimalist text and code editor for Linux, built with C++ and Qt6 QML.

## Installation

### Install from Pre-Compiled Release (Recommended)

1. Download the `ChaoticNotepad-*-linux-x86_64.tar.xz` file from the **Releases** page.
2. Extract the archive, go to the extracted folder (in the terminal) and run:

```bash
./install-app.sh
```

This installs for your user only, so it does not need sudo. It adds the app to your menu and adds the `ChaoticNotepad` command to `~/.local/bin` (that folder must be on your PATH for the command to work).

### Use AppImage (Recommended)

1. Download `ChaoticNotepad-*-x86_64.AppImage` from the **Releases** page.
2. Make it executable and run it:

```bash
chmod +x ChaoticNotepad-*-x86_64.AppImage
./ChaoticNotepad-*-x86_64.AppImage
```

### Build and Install from Source (Alternative)

If you prefer to clone the repository and build natively from source:

1. Ensure you have the prerequisites installed: a C++17 compiler, CMake, and Qt 6.10 or newer.

   Note: `CMakeLists.txt` uses `qt_standard_project_setup(REQUIRES 6.10)`. So if your distribution's Qt is older (for example on Ubuntu), you have to either install Qt 6.10 manually or use the AppImage.

 - Fedora: `sudo dnf install cmake gcc-c++ qt6-qtdeclarative-devel qt6-qtwayland`
 - Arch Linux: `sudo pacman -S cmake gcc qt6-declarative qt6-wayland`
 - Ubuntu / Debian:
    `sudo apt install cmake g++ libgl1-mesa-dev qt6-declarative-dev 
       qml6-module-qtquick-controls qml6-module-qtquick-layouts 
       qml6-module-qtquick-window qt6-wayland`

2. Clone and build. This installs into `/usr/local`:

```bash
git clone https://github.com/ChandanDasGIT/ChaoticNotepad.git
cd ChaoticNotepad
sudo ./install.sh
```

This replaces a copy installed from the `.tar.xz` release, so only one copy is left. Your settings stay.

## Uninstallation

If installed from the `.tar.xz` release, run this from the extracted folder, without sudo. Your documents and settings stay:

```bash
./uninstall-app.sh
```

If installed from source, run this from the cloned folder:

```bash
sudo ./uninstall.sh
```

If you used the AppImage, nothing was installed: just delete the file.

## Where it keeps your data

Settings and changed shortcuts are saved in `~/.config/ChaoticNotepad/ChaoticNotepad.conf`.

## Updates

Once a day the app asks GitHub for the latest version. Nothing else is sent. When a new one is out, a green dot appears in the bottom bar, before Find. Click it to open **Settings > About**. To stop the daily check, turn off **Check for updates** there.

Nothing updates until you choose to:

- **Tarball and AppImage:** **Update now** downloads the new version and checks its signature. It asks about unsaved tabs, restarts the app and opens your files again. If the new version does not start, the old one comes back.
- **Installed with `sudo ./install.sh`:** this needs root, so the app shows a link to the release page instead. Update the project and run `sudo ./install.sh` again.

### How updates are signed

Every release has `update-manifest.txt`, which lists the version and the SHA-256 of each download, and `update-manifest.txt.sig`, its Ed25519 signature. The app has the public key built in and installs an update only if the signature, the version and the file's hash are all correct.

Public key:

```text
08b22dbf2cb4e6435e867e46ed61f2739a37b497d3915aea86f86177be459515
```

The private key is never in this repository. The release workflow reads it from the GitHub secrets `UPDATE_SIGNING_KEY_BASE64` and `UPDATE_SIGNING_KEY_PASSWORD`, and `packaging/sign-update.sh` signs the release. A tag without those secrets stops before anything is published.

### Features:

Editing
- Multiple cursors: Alt+click, add a cursor above or below, add the next occurrence of the selection, select every occurrence. Typing and editing apply to all cursors in one undo step.
- Undo and redo with small stored steps, so long sessions on big files use little memory.
- Auto-indent, Tab and Shift+Tab to indent and outdent. A file that is already indented keeps its own style (tabs or spaces, and how many). Other files and new tabs use your setting, and changing the setting applies it to all open tabs.
- Brackets and quotes close automatically (can be switched off).
- Move, duplicate and delete whole lines.
- Long lines wrap to the window. Up and Down move one screen row at a time.
- Word and line movement and selection with the keyboard.

Code features
- Syntax highlighting for C/C++, JavaScript, Rust, QML, Lua, Fish, shell scripts and CMake.
- Code folding, by brackets or by indentation (for example Python), with fold and unfold all.
- Sticky scrolling: the headers of the blocks you are inside stay pinned at the top.
- Line-number gutter that marks changed lines: red for unsaved changes, green for changes already saved, no mark for untouched lines.
- Minimap showing the whole document, with the visible part, the cursor, selections, search matches and changed lines marked. Click or drag it to scroll.

Search
- Find and replace with match case, whole word, regular expressions and "in selection".
- Match counter ("3 of 12"), next and previous match, and a "Search wrapped" message when the search goes around.
- Replace and Replace all. In regex mode the replacement can use captured groups ($1, \1).
- Select all matches at once.
- App shortcuts such as save and switching tabs keep working while you type in the find bar.

Files and tabs
- Tabs with an unsaved marker, drag-and-drop reordering, reopen of the last closed tab, and keyboard switching.
- Open existing files from the command line: `ChaoticNotepad file1.txt file2.txt`
- Drop files on the window to open them.
- Built-in file browser for Open and Save as, with a type-to-filter list, typed paths including ~, and a hidden files toggle.
- Safe saving through a temporary file, so a crash cannot leave a half-written file. A saved file always ends with a newline.
- Line endings (LF or CRLF) and UTF-8 BOM are kept as they were. A file with mixed line endings is saved unchanged until you edit it, then it uses its most common ending and tells you.
- Binary files, and files over 50 MB, are refused with a message instead of being damaged.
- Detects when the file in the current tab changes or is deleted on disk. A file with no unsaved edits reloads by itself. Otherwise you can reload it, keep your version, or open the disk copy in a new tab.
- Save as will not overwrite a file that is open in another tab.
- Prompt before closing a file with unsaved changes ("Don't save" is shown in red).

Interface
- Dark and light themes.
- Settings: theme, font (searchable list of every installed font), font size, indent width, tabs or spaces, closing brackets and quotes, the minimap, and hiding the mouse pointer while you type.
- Editable keyboard shortcuts with restore defaults, in the settings (the toolbar's Shortcuts button opens them directly).
- An About section with the version, the Qt version, the license and the source code link.
- A green dot in the bottom bar when a new version is out. The update is your choice: Update now in the About section downloads it, checks its signature and restarts the app. If the new version does not start, the old one comes back. Tarball and AppImage installs only: an install with `sudo ./install.sh` gets a link to the release page. The daily check can be switched off.
- When you close the app, it shows each unsaved tab in turn and asks whether to save it. Cancel keeps the app open.
- Status bar with the latest message, cursor position, selection and cursor counts, lines, words, paragraphs, indent setting, encoding, line ending and language.

Packaging
- AppImage and tar.xz releases for Linux x86_64 with Qt included, plus install scripts for the menu entry and the "ChaoticNotepad" command.

## How it is built

The editor engine in `backend/` is plain C++17 with no Qt. `wrapper/` connects it to the QML screens in `frontend/`. `EducationPurpose/` has the full file tree (`architecture.txt`) and diagrams of how the parts connect (`ChaoticNotepadMap.pdf`).

## License

GNU General Public License v3. See `LICENSE`.
