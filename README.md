ChaoticNotepad 2.0 is a Qt 6 / QML text and code editor for Linux. The editing engine is plain C++17 and does not depend on Qt.

Editing
- Multiple cursors: Alt+click, add a cursor above or below, add the next occurrence of the selection, select every occurrence. Typing and editing apply to all cursors in one undo step.
- Undo and redo with small stored steps, so long sessions on big files use little memory.
- Auto-indent, Tab and Shift+Tab to indent and outdent, with the indent style (tabs or spaces, and how many) detected from each file.
- Brackets and quotes close automatically.
- Move, duplicate and delete whole lines.
- Word and line movement and selection with the keyboard.

Code features
- Syntax highlighting for C/C++, JavaScript, Rust, QML, Lua, Fish, shell scripts and CMake.
- Code folding, by brackets or by indentation (for example Python), with fold and unfold all.
- Sticky scrolling: the headers of the blocks you are inside stay pinned at the top.
- Line-number gutter that marks changed lines: red for unsaved changes, green for changes already saved, gray for untouched lines.
- Minimap showing the whole document, with the visible part, the cursor, selections, search matches and changed lines marked. Click or drag it to scroll.

Search
- Find and replace with match case, whole word, regular expressions and "in selection".
- Match counter ("3 of 12"), next and previous match, and a "Search wrapped" message when the search goes around.
- Replace and Replace all. In regex mode the replacement can use captured groups ($1, \1).
- Select all matches at once.

Files and tabs
- Tabs with an unsaved marker, drag-and-drop reordering, reopen of the last closed tab, and keyboard switching.
- Open files from the command line: ChaoticNotepad file1.txt file2.txt
- Built-in file browser for Open and Save as, with a type-to-filter list, typed paths including ~, and a hidden files toggle.
- Safe saving through a temporary file, so a crash cannot leave a half-written file.
- Line endings (LF or CRLF) and UTF-8 BOM are kept as they were. The encoding is checked, and files that are not valid text, or are too big, are refused with a message instead of being damaged.
- Detects when a file changes or is deleted on disk, and lets you reload it, keep your version, or open the disk copy in a new tab.
- Prompt before closing a file with unsaved changes ("Don't save" is shown in red).

Interface
- Dark and light themes.
- Settings: font (searchable list of every installed font), font size, indent style.
- Editable keyboard shortcuts with restore defaults, and a shortcuts list you can open from the toolbar.
- Status bar with cursor position, lines, words, paragraphs and indent setting.
  
Packaging
- AppImage and tar.xz releases for Linux x86_64 with Qt included, plus install scripts for the menu entry and the "ChaoticNotepad" command.
