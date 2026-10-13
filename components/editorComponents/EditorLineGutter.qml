import QtQuick
import NotepadQtQuick

Rectangle {
    id: root

    required property QtObject appPalette
    required property var editor
    property Flickable flick: null
    property string diskContent: ""
    property string originalContent: ""

    property string editorFontFamily: "Monospace"
    property int editorFontSize: 13

    width: 45
    color: appPalette.editorBg
    z: 1

    // One entry per logical line (kept as plain arrays, no per-line objects)
    property var lineOffsets: [0]
    property var lineStates: [0]
    property int lineCount: 1
    property int layoutVersion: 0

    // Only as many rows as fit on screen exist; they are reused while scrolling
    property int firstLine: 0
    readonly property int rowCount: flick ? Math.ceil(flick.height / fontMetrics.height) + 4 : 0

    FontMetrics {
        id: fontMetrics
        font.family: root.editorFontFamily
        font.pixelSize: root.editorFontSize
    }

    LineDiffer { id: differ }

    function realText() { return editor.text; }

    // Index of the line that contains text position `pos`
    function lineOfPos(pos) {
        var lo = 0, hi = lineOffsets.length - 1;
        while (lo < hi) {
            var mid = (lo + hi + 1) >> 1;
            if (lineOffsets[mid] <= pos) lo = mid;
            else hi = mid - 1;
        }
        return lo;
    }

    function updateVisible() {
        if (!flick || !editor) return;
        var line = lineOfPos(editor.positionAt(0, flick.contentY));
        if (line !== firstLine) firstLine = line;
    }

    function recomputeGutter() {
        if (!editor) return;

        var text = editor.text;

        var offs = [0];
        var idx = -1;
        while ((idx = text.indexOf("\n", idx + 1)) !== -1)
            offs.push(idx + 1);

        var unsaved = differ.diff(root.diskContent, text);
        // When both baselines are the same, the second diff would give the same answer
        var saved = (root.originalContent === root.diskContent)
        ? unsaved
        : differ.diff(root.originalContent, text);

        var states = new Array(offs.length);
        for (var i = 0; i < offs.length; ++i)
            states[i] = unsaved[i] > 0 ? 1 : (saved[i] > 0 ? 2 : 0);

        lineOffsets = offs;
        lineStates = states;
        lineCount = offs.length;
        layoutVersion++;
        updateVisible();
    }

    Timer {
        id: gutterTimer
        interval: root.lineCount > 5000 ? 150 : 30
        onTriggered: root.recomputeGutter()
    }

    Connections {
        target: root.editor
        // Layout moved: just re-place the visible rows, no need to redo the diff
        function onContentHeightChanged() { root.layoutVersion++; root.updateVisible(); }
        function onTextChanged()          { gutterTimer.restart(); }
    }

    Connections {
        target: root.flick
        function onContentYChanged() { root.updateVisible(); }
    }

    onFlickChanged: updateVisible()
    onDiskContentChanged: gutterTimer.restart()
    onOriginalContentChanged: gutterTimer.restart()
    Component.onCompleted: recomputeGutter()

    Item {
        anchors.fill: parent

        Repeater {
            model: root.rowCount

            delegate: Item {
                id: row
                required property int index
                readonly property int lineIdx: root.firstLine + index
                readonly property bool valid: lineIdx < root.lineCount

                width: root.width
                height: fontMetrics.height
                visible: valid

                y: {
                    root.layoutVersion;   // re-place the row whenever the layout changes
                    return valid ? root.editor.positionToRectangle(root.lineOffsets[lineIdx]).y : 0;
                }

                Rectangle {
                    width: 3
                    height: parent.height
                    anchors.right: parent.right
                    visible: row.valid && root.lineStates[row.lineIdx] > 0
                    color: root.lineStates[row.lineIdx] === 1 ? "#e67e22" : "#2ecc71"
                }

                Text {
                    text: row.valid ? (row.lineIdx + 1).toString() : ""
                    color: root.appPalette.textMuted
                    font.family: root.editorFontFamily
                    font.pixelSize: root.editorFontSize
                    anchors.fill: parent
                    anchors.rightMargin: 8
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
