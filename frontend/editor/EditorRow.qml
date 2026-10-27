import QtQuick

// The text part of one row of the editor: selection, find matches, coloured text, fold "..." and cursors.
// It only draws what it is given. (The line number and fold arrow are the gutter's job: see GutterCell.)
// A row is either a row of the rows model (CodeEditor's list) or a pinned line at the top (sticky scroll).
// All positions are in CELLS: one cell is one character of the monospace font.
Item {
    id: root

    // ---- the data of the row ----
    property int length: 0                // the row's text length in cells
    property var spans: []                // [{start, text, kind, bold, italic, underline}]: coloured pieces, start in cells
    property var selection: []            // [{from, to}]: selected cells; to == length + 1 means the line break is selected
    property var cursors: []              // [{cell, main}]
    property var matches: []              // [{from, to, current}]: find matches
    property var brackets: []             // [cell, ...]: brackets to highlight
    property string foldTail: ""          // the text shown after "..." on a folded line, e.g. "}"
    property bool foldPill: false         // draw the "..." after the text (the last row of a folded header)
    property bool foldSelected: false     // that "..." is part of the selection
    property bool isCursorLine: false

    // ---- how to draw it (set by the editor) ----
    property real cellWidth: 10
    property bool cursorVisible: true
    property bool opaque: false           // draw our own background (pinned lines are on top of other rows)

    readonly property real textLeft: Theme.textPadding

    // ---- backgrounds ----
    Rectangle {
        visible: root.opaque
        anchors.fill: parent
        color: Theme.editorBg
    }
    Rectangle {                               // the line with the cursor
        visible: root.isCursorLine
        anchors.fill: parent
        color: Theme.currentLineBg
    }

    // ---- find matches ----
    Repeater {
        model: root.matches
        Rectangle {
            required property var modelData
            x: root.textLeft + modelData.from * root.cellWidth
            width: (modelData.to - modelData.from) * root.cellWidth
            height: root.height
            radius: 2
            color: modelData.current ? Theme.findCurrentBg : Theme.findMatchBg
        }
    }

    // ---- selection ----
    Repeater {
        model: root.selection
        Rectangle {
            required property var modelData
            x: root.textLeft + modelData.from * root.cellWidth
            width: (modelData.to - modelData.from) * root.cellWidth
            height: root.height
            color: Theme.selectionBg
        }
    }

    // ---- matching brackets ----
    Repeater {
        model: root.brackets
        Rectangle {
            required property var modelData
            x: root.textLeft + modelData * root.cellWidth
            width: root.cellWidth
            height: root.height
            color: Theme.bracketBg
            border.width: 1
            border.color: Theme.bracketBorder
        }
    }

    // ---- the text: every coloured piece sits at its own cell, so nothing drifts ----
    Repeater {
        model: root.spans
        Text {
            required property var modelData
            x: root.textLeft + modelData.start * root.cellWidth
            y: Math.round((root.height - implicitHeight) / 2)
            text: modelData.text
            textFormat: Text.PlainText
            color: Theme.syntaxColor(modelData.kind)
            font.family: Theme.editorFontFamily
            font.pixelSize: Theme.editorFontSize
            font.bold: modelData.bold || Theme.syntaxBold(modelData.kind)
            font.italic: modelData.italic
            font.underline: modelData.underline
        }
    }

    // ---- the "..." after a folded line ----
    Rectangle {
        visible: root.foldPill
        x: root.textLeft + (root.length + 1) * root.cellWidth
        anchors.verticalCenter: parent.verticalCenter
        width: foldText.implicitWidth + 12
        height: root.height - 6
        radius: 3
        color: root.foldSelected ? Theme.selectionBg : Theme.foldPillBg
        Text {
            id: foldText
            anchors.centerIn: parent
            text: Icon.more + (root.foldTail !== "" ? "  " + root.foldTail : "")
            font.family: root.foldTail !== "" ? Theme.editorFontFamily : Icon.fontFamily
            font.pixelSize: Theme.editorFontSize - 4
            color: Theme.textDim
        }
    }

    // ---- cursors ----
    Repeater {
        model: root.cursors
        Rectangle {
            required property var modelData
            visible: root.cursorVisible
            x: root.textLeft + modelData.cell * root.cellWidth - Theme.cursorWidth / 2
            y: 1
            width: Theme.cursorWidth
            height: root.height - 2
            color: modelData.main ? Theme.cursor : Theme.cursorExtra
        }
    }
}
