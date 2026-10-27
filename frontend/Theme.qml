pragma Singleton
import QtQuick

// Every colour and size of the app lives here. Use it anywhere as Theme.editorBg, Theme.accent, ...
// The colours come from the ChaoticNotepad 1.0 screenshots (One Dark palette).
QtObject {
    property bool isDark: true                    // the settings dialog switches this; every colour below follows it

    // ---- surfaces ----
    readonly property color editorBg:      isDark ? "#1e2227" : "#fafafa"   // the text area, the active tab, the minimap
    readonly property color gutterBg:      isDark ? "#181a1f" : "#f0f0f1"   // line numbers, the bottom bar
    readonly property color tabBarBg:      isDark ? "#21252b" : "#eaeaeb"   // the tab strip behind the tabs
    readonly property color tabActiveBg:   isDark ? "#1e2227" : "#fafafa"
    readonly property color bottomBarBg:   isDark ? "#181a1f" : "#f0f0f1"
    readonly property color statusBarBg:   isDark ? "#21252b" : "#eaeaeb"
    readonly property color dialogBg:      isDark ? "#282c34" : "#f2f2f3"   // Settings and other dialogs
    readonly property color fieldBg:       isDark ? "#1e2227" : "#ffffff"   // combo boxes, buttons, number fields in dialogs
    readonly property color divider:       isDark ? "#181a1f" : "#dbdbdc"

    // ---- text ----
    readonly property color text:          isDark ? "#abb2bf" : "#383a42"
    readonly property color textDim:       isDark ? "#5b626f" : "#9d9d9f"   // line numbers, the tab close button
    readonly property color textDisabled:  isDark ? "#3a3f47" : "#c2c2c4"   // Undo / Redo when there is nothing to undo
    readonly property color iconDefault:   isDark ? "#797e89" : "#696c77"   // toolbar icons
    readonly property color hoverBg:       isDark ? "#21252b" : "#e2e2e3"   // a toolbar button under the mouse
    readonly property color textMuted:     isDark ? "#7b828d" : "#696c77"   // small dialog labels

    // ---- accents ----
    readonly property color accent:        isDark ? "#528bff" : "#4078f2"   // switches that are on

    // ---- sizes ----
    readonly property int tabBarHeight:    35
    readonly property int bottomBarHeight: 37
    readonly property int statusBarHeight: 24
    readonly property int minimapWidth:    70
    readonly property int gutterPadding:   12          // space left and right of the line numbers
    readonly property int toolbarMargin:   16          // space at the left and right ends of the bottom bar
    readonly property int toolbarButtonPadding: 9      // space inside a toolbar button, left and right
    readonly property int toolbarGroupGap: 12          // extra space between the groups (Save As | Undo)
    readonly property int toolbarIconSize: 16
    readonly property int toolbarIconGap:  8           // between a toolbar icon and its label
    readonly property int statusFontSize: 11
    readonly property int statusItemGap:  18

    // ---- Minimap ----

    readonly property int   minimapPixel:        2            // screen pixels per minimap pixel
    readonly property int   minimapStrip:        3            // width of the left and right mark strips
    readonly property color minimapBg:           isDark ? "#1e2227" : "#fafafa"
    readonly property color minimapViewport:     isDark ? "#33ffffff" : "#22000000"  // the shaded part that is on screen
    readonly property color minimapSelection:    isDark ? "#56b6c2" : "#0184bc"
    readonly property color minimapCursor:       isDark ? "#ffffff" : "#000000"
    readonly property color minimapFind:         isDark ? "#9a7b3c" : "#d9b15a"
    readonly property color minimapFindCurrent:  isDark ? "#e5a04a" : "#c18401"
    
    // ---- tab bar ----
    readonly property color tabHoverBg:    isDark ? "#262a31" : "#e2e2e3"
    readonly property int tabMinWidth:     90
    readonly property int tabMaxWidth:     200
    readonly property int tabPadding:      12
    readonly property int tabCloseSize:    16
    readonly property int tabAccentHeight: 2
    readonly property int tabFontSize:     12
    readonly property int addTabWidth:     36

    // ---- find bar ----
    readonly property int   findFieldHeight:  26
    readonly property color findBarBg:        isDark ? "#21252b" : "#eaeaeb"
    readonly property color findFieldBg:      isDark ? "#1b1d23" : "#ffffff"
    readonly property color findFieldBorder:  isDark ? "#3b4048" : "#c8c8ca"
    readonly property color findError:        isDark ? "#e06c75" : "#e45649"
    
    // ---- editor ----
    readonly property color selectionBg:       isDark ? "#3e4451" : "#cfd8ea"
    readonly property color currentLineBg:     isDark ? "#252a31" : "#f0f0f1"
    readonly property color cursor:            isDark ? "#528bff" : "#4078f2"
    readonly property color cursorExtra:       isDark ? "#8aa9e6" : "#7b9bf0"
    readonly property color findMatchBg:       isDark ? "#40e5c07b" : "#40c18401"
    readonly property color findCurrentBg:     isDark ? "#80e5c07b" : "#80c18401"
    readonly property color bracketBg:         isDark ? "#33528bff" : "#334078f2"
    readonly property color bracketBorder:     isDark ? "#528bff" : "#4078f2"
    readonly property color gutterText:        isDark ? "#5b626f" : "#9d9d9f"
    readonly property color gutterTextActive:  isDark ? "#abb2bf" : "#383a42"
    readonly property color danger:            isDark ? "#c93c3c" : "#c0392b"   // destructive buttons
    readonly property color changeUnsaved:     isDark ? "#b8292a" : "#b8292a"   // dark red
    readonly property color changeSaved:       isDark ? "#2fc24b" : "#1f9d3a"   // clear green
    readonly property color foldPillBg:        isDark ? "#2c313a" : "#e5e5e6"
    readonly property color stickyDivider:     isDark ? "#181a1f" : "#dbdbdc"
    readonly property color scrollbarHandle:        isDark ? "#4b525e" : "#c2c2c4"
    readonly property color scrollbarHandleHover:   isDark ? "#5d6573" : "#a9a9ab"
    readonly property color scrollbarHandlePressed: isDark ? "#6f7888" : "#8f8f92"
    readonly property int gutterLeft: 14
    readonly property int gutterFold: 18        // room for the fold arrow, right of the line number
    readonly property int gutterRight:    10     // space right of the line numbers
    readonly property int textPadding:    6      // between the gutter and the text
    readonly property int cursorWidth:    2
    readonly property int scrollbarWidth: 0      // scrollbar
    readonly property int wheelRows:      3      // rows per notch of the mouse wheel

    // the colour of each syntax token, in the order of the engine's Token enum:
    // None, Keyword, Type, Function, Number, String, Comment, Preprocessor, Constant,
    // Variable, Property, Attribute, Class, Identifier, Modifier
    readonly property var syntaxColors: isDark ? [
        "#abb2bf", "#c678dd", "#61afef", "#61afef", "#98c379", "#98c379", "#5c6370", "#e5c07b",
        "#d19a66", "#e06c75", "#e06c75", "#d19a66", "#e5c07b", "#d19a66", "#c678dd"
    ] : [
        "#383a42", "#a626a4", "#c18401", "#4078f2", "#986801", "#50a14f", "#a0a1a7", "#c18401",
        "#986801", "#e45649", "#e45649", "#986801", "#c18401", "#986801", "#a626a4"
    ]
    function syntaxColor(kind) {
        return kind >= 0 && kind < syntaxColors.length ? syntaxColors[kind] : text
    }
    function syntaxBold(kind) { return kind === 1 || kind === 14 }   // keywords and modifiers

    // ---- fonts ----
    property string editorFontFamily: "Noto Sans Mono"
    property int    editorFontSize:   16
    readonly property int editorLineHeight: Math.round(editorFontSize * 1.375)
    readonly property int    uiFontSize:       12

    // ---- settings dialog ----
    readonly property color scrim:     isDark ? "#99000000" : "#66000000"
    readonly property color switchOff: isDark ? "#4b5263" : "#c8c8ca"
}
