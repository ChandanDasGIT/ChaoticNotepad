import QtQuick

Rectangle {
    id: root

    required property QtObject appPalette
    required property var editor
    property string diskContent: ""
    property string editorFontFamily: "Monospace"
    property int editorFontSize: 13

    width: 62
    color: appPalette.editorBg
    z: 1

    property var gutterData: []
    property int layoutVersion: 0
    property var foldStorage: ({})

    FontMetrics {
        id: fontMetrics
        font.family: root.editorFontFamily
        font.pixelSize: root.editorFontSize
    }

    function recomputeGutter() {
        if (!editor) return;

        var fullText = editor.text;
        var lines = fullText.split("\n");
        var diskLines = root.diskContent.split("\n");

        var offsets = [];
        var pos = 0;
        for (var i = 0; i < lines.length; i++) {
            offsets.push(pos);
            pos += lines[i].length + 1;
        }

        var items = [];
        var accumulatedHiddenLines = 0;

        for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
            var lineStr = lines[lineIdx];
            var foldMatch = lineStr.match(/(\{|\(|\[)\s*\/\*folded:(\d+)\*\/\s*\.\.\.\s*(\}|\)|\])/);
            var isFolded = foldMatch !== null;
            var hasFoldTarget = /[\{\(\[]/.test(lineStr);

            var endLine = -1;
            if (hasFoldTarget && !isFolded) {
                var firstBracePos = lineStr.search(/[\{\(\[]/);
                var openCh = lineStr.charAt(firstBracePos);
                var closeCh = (openCh === '{') ? '}' : ((openCh === '(') ? ')' : ']');

                var depth = 0;
                var foundEnd = false;

                for (var j = lineIdx; j < lines.length; j++) {
                    var searchStart = (j === lineIdx) ? firstBracePos : 0;
                    for (var k = searchStart; k < lines[j].length; k++) {
                        var ch = lines[j].charAt(k);
                        if (ch === openCh) {
                            depth++;
                        } else if (ch === closeCh) {
                            depth--;
                            if (depth === 0) {
                                endLine = j;
                                foundEnd = true;
                                break;
                            }
                        }
                    }
                    if (foundEnd) break;
                }
            }

            var modState = 0;
            if (lineIdx < diskLines.length) {
                if (lines[lineIdx] !== diskLines[lineIdx]) {
                    modState = 1;
                }
            } else {
                modState = 1;
            }

            var actualLineNumber = lineIdx + 1 + accumulatedHiddenLines;

            items.push({
                lineNum: actualLineNumber,
                offset: offsets[lineIdx],
                isFoldable: (hasFoldTarget && endLine > lineIdx) || isFolded,
                isFolded: isFolded,
                modState: modState,
                startLine: lineIdx,
                endLine: endLine
            });

            if (isFolded) {
                accumulatedHiddenLines += parseInt(foldMatch[2], 10);
            }
        }

        gutterData = items;
        layoutVersion++;
    }

    function toggleFold(item) {
        var lines = editor.text.split("\n");
        if (item.isFolded) {
            var foldedLine = lines[item.startLine];
            var stored = foldStorage[item.startLine];
            if (stored !== undefined) {
                var restored = foldedLine.replace(/(\{|\(|\[)\s*\/\*folded:\d+\*\/\s*\.\.\.\s*(\}|\)|\])/, stored);
                lines[item.startLine] = restored;
                delete foldStorage[item.startLine];
                editor.text = lines.join("\n");
            }
        } else {
            if (item.endLine <= item.startLine) return;
            var blockLines = lines.slice(item.startLine, item.endLine + 1);
            var blockText = blockLines.join("\n");

            var firstBraceIdx = blockText.search(/[\{\(\[]/);
            if (firstBraceIdx === -1) return;

            var openCh = blockText.charAt(firstBraceIdx);
            var closeCh = (openCh === '{') ? '}' : ((openCh === '(') ? ')' : ']');

            var lastBraceIdx = blockText.lastIndexOf(closeCh);
            if (lastBraceIdx === -1) return;

            var hiddenLinesCount = item.endLine - item.startLine;
            var hiddenSlice = blockText.substring(firstBraceIdx, lastBraceIdx + 1);
            foldStorage[item.startLine] = hiddenSlice;

            var collapsedBlock = blockText.substring(0, firstBraceIdx) + openCh + " /*folded:" + hiddenLinesCount + "*/ ... " + closeCh;
            lines.splice(item.startLine, (item.endLine - item.startLine + 1), collapsedBlock);
            editor.text = lines.join("\n");
        }
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
                    anchors.left: parent.left
                    anchors.right: foldBtn.left
                    anchors.rightMargin: 4
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    height: parent.height
                }

                Text {
                    id: foldBtn
                    width: 14
                    height: parent.height
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    visible: modelData.isFoldable
                    text: modelData.isFolded ? "▶" : "▼"
                    font.pixelSize: 10
                    color: foldMouse.containsMouse ? root.appPalette.highlight : root.appPalette.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        id: foldMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFold(modelData)
                    }
                }
            }
        }
    }
}
