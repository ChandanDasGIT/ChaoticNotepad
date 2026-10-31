pragma Singleton
import QtQuick

// Every icon of the app is a glyph of one icon font (Font Awesome 6 Free, Solid).
// Each icon is written as a unicode escape: "\uf002" is the magnifying glass.
// Use it anywhere like this:
//     Text { text: Icon.search; font.family: Icon.fontFamily }
// To add an icon: look up its code on fontawesome.com and add a line below, for example
//     readonly property string cloud: "\uf0c2"   // cloud
// Only SOLID icons of the free set exist in frontend/fonts/fa-solid-900.ttf.
QtObject {
    // The font file is a resource of the app (see RESOURCES in CMakeLists.txt).
    readonly property FontLoader loader: FontLoader { source: "fonts/fa-solid-900.ttf" }
    readonly property string fontFamily: loader.name

    // ---- bottom toolbar ----
    readonly property string newFile:       "\uf15b"   // file
    readonly property string openFolder:    "\uf07c"   // folder-open
    readonly property string save:          "\uf0c7"   // floppy-disk
    readonly property string saveAs:        "\uf56e"   // file-export
    readonly property string undo:          "\uf0e2"   // arrow-rotate-left
    readonly property string redo:          "\uf01e"   // arrow-rotate-right
    readonly property string search:        "\uf002"   // magnifying-glass
    readonly property string keyboard:      "\uf11c"   // keyboard
    readonly property string settings:      "\uf013"   // gear
    readonly property string palette:       "\uf53f"   // palette: settings, appearance
    readonly property string pen:           "\uf304"   // pen: settings, editor
    readonly property string info:          "\uf05a"   // circle-info: settings, about

    // ---- tabs and dialogs ----
    readonly property string close:         "\uf00d"   // xmark
    readonly property string add:           "\uf067"   // plus
    readonly property string remove:        "\uf068"   // minus
    readonly property string check:         "\uf00c"   // check
    readonly property string dot:           "\uf111"   // circle (the modified dot on a tab)
    readonly property string more:          "\uf141"   // ellipsis

    // ---- arrows ----
    readonly property string chevronUp:     "\uf077"   // chevron-up
    readonly property string chevronDown:   "\uf078"   // chevron-down
    readonly property string chevronLeft:   "\uf053"   // chevron-left
    readonly property string chevronRight:  "\uf054"   // chevron-right
    readonly property string caretUp:       "\uf0d8"   // caret-up
    readonly property string caretDown:     "\uf0d7"   // caret-down
    readonly property string arrowUp:       "\uf062"   // arrow-up: find, previous match
    readonly property string arrowDown:     "\uf063"   // arrow-down: find, next match

    // ---- files ----
    readonly property string folder:        "\uf07b"   // folder
    readonly property string file:          "\uf15b"   // file
    readonly property string copy:          "\uf0c5"   // copy
    readonly property string trash:         "\uf1f8"   // trash
}
