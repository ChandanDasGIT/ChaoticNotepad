import QtQuick
import NotepadQtQuick

Rectangle {
    id: root

    required property QtObject appPalette
    required property var editor
    property string diskContent: ""
    property string originalContent: ""

    property string editorFontFamily: "Monospace"
    property int editorFontSize: 13

    width: 45 // Slightly narrower now that fold buttons are gone
    color: appPalette.editorBg
    z: 1

    property var gutterData: []
    property int layoutVersion: 0

    FontMetrics {
        id: fontMetrics
        font.family: root.editorFontFamily
        font.pixelSize: root.editorFontSize
    }

    LineDiffer { id: differ }

    function realText() { return editor.text; }

    function recomputeGutter() {
        if (!editor) return;

        var lines = editor.text.split("\n");
        var unsavedStates = differ.diff(root.diskContent, editor.text);
        var savedStates = differ.diff(root.originalContent, editor.text);

        var items = [];
        var pos = 0;
        for (var i = 0; i < lines.length; ++i) {
            var offset = pos;
            pos += lines[i].length + 1;

            var modState = 0;
            if (unsavedStates[i] > 0) modState = 1;
            else if (savedStates[i] > 0) modState = 2;

            items.push({
                lineNum: i + 1,
                offset: offset,
                modState: modState,
                startLine: i
            });
        }

        gutterData = items;
        layoutVersion++;
    }

    Timer {
        id: gutterTimer
        interval: 30
        onTriggered: root.recomputeGutter()
    }

    Connections {
        target: editor
        function onContentHeightChanged() { gutterTimer.restart(); }
        function onTextChanged()          { gutterTimer.restart(); }
    }

    onDiskContentChanged: gutterTimer.restart()
    onOriginalContentChanged: gutterTimer.restart()
    Component.onCompleted: recomputeGutter()

    Item {
        anchors.fill: parent

        Repeater {
            model: root.gutterData

            Item {
                width: root.width
                height: fontMetrics.height
                y: root.layoutVersion >= 0 ? root.editor.positionToRectangle(modelData.offset).y : 0

                Rectangle {
                    width: 3
                    height: parent.height
                    anchors.right: parent.right
                    visible: modelData.modState > 0
                    color: modelData.modState === 1 ? "#e67e22" : "#2ecc71"
                }

                Text {
                    text: modelData.lineNum.toString()
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
