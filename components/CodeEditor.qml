import QtQuick
import QtQuick.Controls
import NotepadQtQuick

Flickable {
    id: editorFlickable
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    required property QtObject appPalette
    property alias text: editor.text
    property alias textEdit: editor

    property int editorFontSize: 13
    property string editorFontFamily: "Monospace"
    property string diskContent: ""
    property string currentFilePath: ""

    signal textModified()
    signal zoomRequested(int delta)

    contentWidth: containerItem.width
    contentHeight: Math.max(height, containerItem.height)

    CppHighlighter {
        id: highlighter
        highlightedWord: editor.selectedText
        cursorPosition: editor.cursorPosition
    }

    function updateHighlighter() {
            if (!editor.textDocument) return;

            var path = currentFilePath.toLowerCase();
            var isSupported = path.endsWith(".cpp") ||
                              path.endsWith(".h")   ||
                              path.endsWith(".hpp") ||
                              path.endsWith(".qml") ||
                              path.endsWith(".cc")  ||
                              path.endsWith(".cxx");

            if (isSupported) {
                highlighter.setDocument(editor.textDocument);
                highlighter.cursorPosition = editor.cursorPosition;
            } else {
                highlighter.clearBracketMatches();
                highlighter.setDocument(null); // Detach cleanly for .txt, .md, untitled
            }
        }

        onCurrentFilePathChanged: updateHighlighter()

    ScrollBar.vertical: ScrollBar {
        parent: editorFlickable
        anchors.top: editorFlickable.top
        anchors.right: editorFlickable.right
        anchors.bottom: editorFlickable.bottom
    }

    MouseArea {
        anchors.fill: parent
        z: 15
        acceptedButtons: Qt.NoButton

        onWheel: function(wheel) {
            if (wheel.modifiers & Qt.ControlModifier) {
                if (wheel.angleDelta.y > 0) {
                    editorFlickable.zoomRequested(1);
                } else if (wheel.angleDelta.y < 0) {
                    editorFlickable.zoomRequested(-1);
                }
                wheel.accepted = true;
            } else {
                wheel.accepted = false;
            }
        }
    }

    Item {
        id: containerItem
        width: editorFlickable.width
        height: Math.max(editor.implicitHeight + 40, editorFlickable.height)

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.IBeamCursor
            onClicked: function(mouse) {
                editor.forceActiveFocus();
                if (mouse.y > editor.implicitHeight) {
                    editor.cursorPosition = editor.text.length;
                } else {
                    var mapped = mapToItem(editor, mouse.x, mouse.y);
                    editor.cursorPosition = editor.positionAt(mapped.x, mapped.y);
                }
            }
        }

        Row {
            id: contentRow
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: lineGutter
                width: 62
                height: parent.height
                color: editorFlickable.appPalette.editorBg

                property var gutterData: []
                property int layoutVersion: 0
                property var foldStorage: ({})

                function recomputeGutter() {
                    var fullText = editor.text;
                    var lines = fullText.split("\n");
                    var diskLines = editorFlickable.diskContent.split("\n");

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

                        // Detect already folded block
                        var foldMatch = lineStr.match(/(\{|\(|\[)\s*\/\*folded:(\d+)\*\/\s*\.\.\.\s*(\}|\)|\])/);
                        var isFolded = foldMatch !== null;

                        // Detect any opening bracket/brace: {, (, [
                        var hasFoldTarget = /[\{\(\[]/.test(lineStr);

                        var endLine = -1;
                        if (hasFoldTarget && !isFolded) {
                            // Find the first opening brace/bracket on this line
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

                        // Kate-style line modification state
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

                Connections {
                    target: editor
                    function onContentHeightChanged() { lineGutter.recomputeGutter() }
                    function onTextChanged() { lineGutter.recomputeGutter() }
                }
                Connections {
                    target: editorFlickable
                    function onDiskContentChanged() { lineGutter.recomputeGutter() }
                }

                Component.onCompleted: recomputeGutter()

                Item {
                    anchors.fill: parent

                    Repeater {
                        model: lineGutter.gutterData

                        Item {
                            width: lineGutter.width
                            height: editor.cursorRectangle.height
                            y: lineGutter.layoutVersion >= 0 ? editor.positionToRectangle(modelData.offset).y : 0

                            // Kate-style modified/saved indicator strip
                            Rectangle {
                                width: 3
                                height: parent.height
                                anchors.right: parent.right
                                visible: modelData.modState > 0
                                color: modelData.modState === 1 ? "#e67e22" : "#2ecc71"
                            }

                            Text {
                                text: modelData.lineNum.toString()
                                color: editorFlickable.appPalette.textMuted
                                font.family: editorFlickable.editorFontFamily
                                font.pixelSize: editorFlickable.editorFontSize
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
                                color: foldMouse.containsMouse ? editorFlickable.appPalette.highlight : editorFlickable.appPalette.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    id: foldMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lineGutter.toggleFold(modelData)
                                }
                            }
                        }
                    }
                }
            }

            TextEdit {
                id: editor
                width: editorFlickable.width - lineGutter.width - 24
                height: Math.max(implicitHeight, editorFlickable.height)
                topPadding: 10
                leftPadding: 6
                bottomPadding: 20
                color: editorFlickable.appPalette.textMain
                font.family: editorFlickable.editorFontFamily
                font.pixelSize: editorFlickable.editorFontSize
                selectByMouse: true
                focus: true
                wrapMode: TextEdit.WrapAnywhere

                selectionColor: editorFlickable.appPalette.textSelectionBg
                selectedTextColor: editorFlickable.appPalette.textSelectedColor

                property bool isHandlingSpecialKey: false

                Component.onCompleted: {
                        editorFlickable.updateHighlighter();
                    }

                cursorDelegate: Rectangle {
                    id: cursorRect
                    width: 2
                    height: editor.cursorRectangle.height > 0 ? editor.cursorRectangle.height : editor.font.pixelSize + 4
                    color: editorFlickable.appPalette ? editorFlickable.appPalette.highlight : "#528bff"
                    visible: editor.activeFocus

                    // Classic text editor blinking animation
                    SequentialAnimation on opacity {
                        running: editor.activeFocus
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.0; duration: 500 }
                        NumberAnimation { to: 0.0; duration: 500 }
                    }
                }
                MouseArea {
                    id: emptyAreaBelowText
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    enabled: emptyAreaBelowText.mouseY > editor.contentHeight + editor.topPadding

                    onClicked: {
                        editor.forceActiveFocus();
                        editor.cursorPosition = editor.text.length;
                    }
                }

                Keys.onPressed: function(event) {
                    var pos = editor.cursorPosition;
                    var doc = editor.text;

                    // 1. Move Lines Up / Down: Alt + Up / Alt + Down
                    // In CodeEditor.qml inside Keys.onPressed:
                    if (event.modifiers === Qt.AltModifier && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                        var isUp = (event.key === Qt.Key_Up);
                        var sStart = (editor.selectionStart !== editor.selectionEnd) ? editor.selectionStart : pos;
                        var sEnd = (editor.selectionStart !== editor.selectionEnd) ? editor.selectionEnd : pos;

                        var blockStart = doc.lastIndexOf("\n", sStart - 1);
                        var startBound = (blockStart === -1) ? 0 : blockStart + 1;
                        var blockEnd = doc.indexOf("\n", sEnd);
                        var endBound = (blockEnd === -1) ? doc.length : blockEnd;

                        var lines = doc.split("\n");
                        var startLine = doc.substring(0, startBound).split("\n").length - 1;
                        var endLine = doc.substring(0, endBound).split("\n").length - 1;

                        if (isUp) {
                            if (startLine > 0) {
                                var aboveLine = lines[startLine - 1];
                                lines.splice(startLine - 1, 1);
                                lines.splice(endLine, 0, aboveLine);
                                var prevLineStart = doc.lastIndexOf("\n", startBound - 2);
                                var replaceStart = (prevLineStart === -1) ? 0 : prevLineStart + 1;
                                var newChunk = lines.slice(startLine - 1, endLine + 1).join("\n");

                                isHandlingSpecialKey = true;
                                editor.remove(replaceStart, endBound);
                                editor.insert(replaceStart, newChunk);
                                var shiftedStart = lines.slice(0, startLine - 1).join("\n").length + (startLine - 1 > 0 ? 1 : 0);
                                var shiftedEnd = lines.slice(0, endLine).join("\n").length;
                                editor.select(shiftedStart, shiftedEnd);
                                isHandlingSpecialKey = false;
                            }
                        } else {
                            if (endLine < lines.length - 1) {
                                var belowLine = lines[endLine + 1];
                                lines.splice(endLine + 1, 1);
                                lines.splice(startLine, 0, belowLine);
                                var nextLineEnd = doc.indexOf("\n", endBound + 1);
                                var replaceEnd = (nextLineEnd === -1) ? doc.length : nextLineEnd;
                                var newChunk2 = lines.slice(startLine, endLine + 2).join("\n");

                                isHandlingSpecialKey = true;
                                editor.remove(startBound, replaceEnd);
                                editor.insert(startBound, newChunk2);
                                var shiftedStart2 = lines.slice(0, startLine + 1).join("\n").length - (lines[startLine + 1].length);
                                var shiftedEnd2 = lines.slice(0, endLine + 2).join("\n").length;
                                editor.select(shiftedStart2, shiftedEnd2);
                                isHandlingSpecialKey = false;
                            }
                        }
                        event.accepted = true;
                        return;
                    }

                    // 2. Tab & Shift+Tab Indentation
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        var isShift = (event.key === Qt.Key_Backtab) || (event.modifiers & Qt.ShiftModifier);

                        if (editor.selectionStart !== editor.selectionEnd) {
                            var selStart = editor.selectionStart;
                            var selEnd = editor.selectionEnd;

                            var bStart = doc.lastIndexOf("\n", selStart - 1);
                            var rStart = (bStart === -1) ? 0 : bStart + 1;
                            var bEnd = doc.indexOf("\n", selEnd);
                            var rEnd = (bEnd === -1) ? doc.length : bEnd;

                            var selectedChunk = doc.substring(rStart, rEnd);
                            var chunkLines = selectedChunk.split("\n");
                            var modifiedLines = [];
                            var netOffsetChange = 0;

                            for (var i = 0; i < chunkLines.length; i++) {
                                var line = chunkLines[i];
                                if (isShift) {
                                    var unindented = line.replace(/^( {1,4}|\t)/, "");
                                    netOffsetChange -= (line.length - unindented.length);
                                    modifiedLines.push(unindented);
                                } else {
                                    modifiedLines.push("    " + line);
                                    netOffsetChange += 4;
                                }
                            }

                            var newChunk = modifiedLines.join("\n");
                            isHandlingSpecialKey = true;
                            editor.remove(rStart, rEnd);
                            editor.insert(rStart, newChunk);
                            editor.select(rStart, rEnd + netOffsetChange);
                            isHandlingSpecialKey = false;
                        } else {
                            if (isShift) {
                                var lStart = doc.lastIndexOf("\n", pos - 1);
                                var sIdx = (lStart === -1) ? 0 : lStart + 1;
                                var linePrefix = doc.substring(sIdx, pos);
                                var spacesToRemove = linePrefix.match(/( {1,4}|\t)$/);
                                if (spacesToRemove) {
                                    isHandlingSpecialKey = true;
                                    editor.remove(pos - spacesToRemove[0].length, pos);
                                    isHandlingSpecialKey = false;
                                }
                            } else {
                                isHandlingSpecialKey = true;
                                editor.insert(pos, "    ");
                                editor.cursorPosition = pos + 4;
                                isHandlingSpecialKey = false;
                            }
                        }
                        event.accepted = true;
                        return;
                    }

                    // 3. Ctrl + / (Comment / Uncomment)
                    if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Slash) {
                        var cLineStart = doc.lastIndexOf("\n", pos - 1);
                        var cStartIdx = (cLineStart === -1) ? 0 : cLineStart + 1;
                        var cLineEnd = doc.indexOf("\n", pos);
                        var cEndIdx = (cLineEnd === -1) ? doc.length : cLineEnd;
                        var currentLine = doc.substring(cStartIdx, cEndIdx);

                        var commentMatch = currentLine.match(/^(\s*)(\/\/ ?)/);
                        isHandlingSpecialKey = true;
                        if (commentMatch) {
                            var stripped = currentLine.replace(/^(\s*)\/\/ ?/, "$1");
                            editor.remove(cStartIdx, cEndIdx);
                            editor.insert(cStartIdx, stripped);
                            editor.cursorPosition = Math.max(cStartIdx, pos - commentMatch[2].length);
                        } else {
                            var indentMatch = currentLine.match(/^(\s*)/);
                            var ws = indentMatch ? indentMatch[1] : "";
                            var rest = currentLine.substring(ws.length);
                            var commented = ws + "// " + rest;
                            editor.remove(cStartIdx, cEndIdx);
                            editor.insert(cStartIdx, commented);
                            editor.cursorPosition = pos + 3;
                        }
                        isHandlingSpecialKey = false;
                        event.accepted = true;
                        return;
                    }

                    // 4. Ctrl + D (Duplicate line or selection)
                    if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_D) {
                        if (editor.selectionStart !== editor.selectionEnd) {
                            var sel = editor.selectedText;
                            var insertAt = editor.selectionEnd;
                            isHandlingSpecialKey = true;
                            editor.insert(insertAt, sel);
                            editor.cursorPosition = insertAt + sel.length;
                            isHandlingSpecialKey = false;
                        } else {
                            var dLineStart = doc.lastIndexOf("\n", pos - 1);
                            var dSIdx = (dLineStart === -1) ? 0 : dLineStart + 1;
                            var dLineEnd = doc.indexOf("\n", pos);
                            var dEIdx = (dLineEnd === -1) ? doc.length : dLineEnd;
                            var fullLine = doc.substring(dSIdx, dEIdx);

                            isHandlingSpecialKey = true;
                            editor.insert(dEIdx, "\n" + fullLine);
                            editor.cursorPosition = pos + fullLine.length + 1;
                            isHandlingSpecialKey = false;
                        }
                        event.accepted = true;
                        return;
                    }

                    // 5. Smart Indent on Enter
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        var charBefore = (pos > 0) ? doc.charAt(pos - 1) : "";
                        var charAfter = (pos < doc.length) ? doc.charAt(pos) : "";

                        if (charBefore === "{" && charAfter === "}") {
                            var brStart = doc.lastIndexOf("\n", pos - 1);
                            var brLine = doc.substring(brStart === -1 ? 0 : brStart + 1, pos - 1);
                            var brIndent = (brLine.match(/^(\s*)/) || ["", ""])[1];
                            var extra = "    ";

                            isHandlingSpecialKey = true;
                            editor.insert(pos, "\n" + brIndent + extra + "\n" + brIndent);
                            editor.cursorPosition = pos + 1 + brIndent.length + extra.length;
                            isHandlingSpecialKey = false;
                            event.accepted = true;
                            return;
                        }

                        var curStart = doc.lastIndexOf("\n", pos - 1);
                        var curLine = doc.substring(curStart === -1 ? 0 : curStart + 1, pos);
                        var matchWs = curLine.match(/^(\s*)/);
                        var leadWs = matchWs ? matchWs[1] : "";

                        if (leadWs.length > 0) {
                            isHandlingSpecialKey = true;
                            editor.insert(pos, "\n" + leadWs);
                            editor.cursorPosition = pos + 1 + leadWs.length;
                            isHandlingSpecialKey = false;
                            event.accepted = true;
                            return;
                        }
                    }

                    // 6. Bracket / Quote Auto-closing
                    var pairs = {
                        "(": ")",
                        "{": "}",
                        "[": "]",
                        "\"": "\"",
                        "'": "'"
                    };

                    if (pairs[event.text] !== undefined) {
                        var openChar = event.text;
                        var closeChar = pairs[openChar];
                        isHandlingSpecialKey = true;
                        editor.insert(pos, openChar + closeChar);
                        editor.cursorPosition = pos + 1;
                        isHandlingSpecialKey = false;
                        event.accepted = true;
                        return;
                    }
                }

                onTextChanged: {
                    editorFlickable.textModified();
                }

                onCursorRectangleChanged: {
                    var cursorBottom = cursorRectangle.y + cursorRectangle.height + bottomPadding;
                    var cursorTop = cursorRectangle.y - topPadding;

                    if (cursorBottom > editorFlickable.contentY + editorFlickable.height) {
                        editorFlickable.contentY = cursorBottom - editorFlickable.height;
                    } else if (cursorTop < editorFlickable.contentY) {
                        editorFlickable.contentY = Math.max(0, cursorTop);
                    }
                }
            }
        }
    }
}