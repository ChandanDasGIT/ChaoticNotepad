import QtQuick

QtObject {
    id: palette

    property bool isDark: true

    // Backgrounds
    readonly property color editorBg: isDark ? "#1e2227" : "#fafafa"
    readonly property color toolbarBg: isDark ? "#181a1f" : "#f0f0f0"
    readonly property color tabBg: isDark ? "#21252b" : "#e6e6e6"
    readonly property color activeTabBg: isDark ? "#1e2227" : "#fafafa"
    readonly property color popupBg: isDark ? "#282c34" : "#ffffff"

    // Foregrounds & Accents
    readonly property color textMain: isDark ? "#abb2bf" : "#24292e"
    readonly property color textMuted: isDark ? "#5c6370" : "#959da5"
    readonly property color highlight: isDark ? "#528bff" : "#0366d6"
    readonly property color border: isDark ? "#181a1f" : "#d1d5da"
    readonly property color danger: isDark ? "#e06c75" : "#d73a49"

    // Icon States
    readonly property color iconNormal: textMuted
    readonly property color iconHover: textMain

    // Selection Colors
    readonly property color textSelectionBg: isDark ? "#264f78" : "#add6ff"
    readonly property color textSelectedColor: isDark ? "#ffffff" : "#000000"

    // Aliases for component compatibility
    readonly property color barBg: toolbarBg
    readonly property color cardBg: popupBg
    readonly property color hoverBg: isDark ? "#2c313a" : "#eaecef"
}