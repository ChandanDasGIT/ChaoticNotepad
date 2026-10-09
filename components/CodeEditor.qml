import QtQuick
import QtQuick.Controls
import NotepadQtQuick
import "./editorComponents"

Item {
    id: root

    required property QtObject appPalette
    property alias text: editor.text
    property alias textEdit: editor

    property int editorFontSize: 13
    property string editorFontFamily: "Monospace"
    property string diskContent: ""
    property string originalContent: ""
    property string currentFilePath: ""
    property bool isProgrammaticChange: false

    property int caretTick: 0
    property int prevCaret: 0
    property int curCaret: 0

    MultiCursor { id: multiCaret }

    Connections {
        target: multiCaret
        function onPositionsChanged() { Qt.callLater(function() { root.caretTick++; }); }
    }

    signal textModified()
    signal zoomRequested(int delta)

    function realText() { return lineGutter.realText(); }

    // Scroll so the text position `pos` is on screen. If it is off-screen,
    // it gets centred; if already comfortably visible, nothing moves.
    function ensureVisible(pos) {
        var r = editor.positionToRectangle(pos);
        var p = editor.mapToItem(editorFlickable.contentItem, r.x, r.y);
        var margin = 30;
        var viewTop = editorFlickable.contentY;
        var viewBottom = viewTop + editorFlickable.height;

        if (p.y >= viewTop + margin && p.y + r.height <= viewBottom - margin)
            return;

        var maxY = Math.max(0, editorFlickable.contentHeight - editorFlickable.height);
        var target = p.y + r.height / 2 - editorFlickable.height / 2;
        editorFlickable.contentY = Math.max(0, Math.min(maxY, target));
    }

    Minimap {
        id: minimap
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 100
        z: 20
        editorFlickable: editorFlickable
        editorTextEdit: editor
        appPalette: root.appPalette
    }

    Flickable {
        id: editorFlickable
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: minimap.left
        clip: false
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds

        contentWidth: containerItem.width
        contentHeight: Math.max(height, containerItem.height)

        property string wordToHighlight: ""

        Timer {
            id: selectionTimer
            interval: 120
            onTriggered: {
                var len = editor.selectionEnd - editor.selectionStart;
                var word = "";
                if (len > 0 && len <= 64) {
                    var t = editor.selectedText;
                    if (t.indexOf("\n") === -1) word = t;
                }
                editorFlickable.wordToHighlight = word;
                highlighter.cursorPosition = editor.cursorPosition;
            }
        }

        Connections {
            target: editor
            function onSelectionStartChanged() { selectionTimer.restart(); }
            function onSelectionEndChanged()   { selectionTimer.restart(); }
            function onCursorPositionChanged() {
                root.prevCaret = root.curCaret;
                root.curCaret = editor.cursorPosition;
                multiCaret.mergeWith(editor.cursorPosition);
                selectionTimer.restart();
                editor.cursorVisible = false;
                Qt.callLater(function() {
                    editor.cursorVisible = true;
                });
            }
        }

        CppHighlighter {
            id: highlighter
            highlightedWord: editorFlickable.wordToHighlight
        }

        function updateHighlighter() {
            if (!editor.textDocument) return;

            highlighter.filePath = root.currentFilePath;

            var path = root.currentFilePath.toLowerCase();
            var isSupported = path.endsWith(".cpp")  ||
                              path.endsWith(".h")    ||
                              path.endsWith(".hpp")  ||
                              path.endsWith(".qml")  ||
                              path.endsWith(".cc")   ||
                              path.endsWith(".cxx")  ||
                              path.endsWith(".lua")  ||
                              path.endsWith(".js")   ||
                              path.endsWith(".fish")   ||
                              path.endsWith(".mjs");

            if (isSupported) {
                highlighter.setDocument(editor.textDocument);
                highlighter.cursorPosition = editor.cursorPosition;
            } else {
                highlighter.clearBracketMatches();
                highlighter.setDocument(null);
            }
        }

        Connections {
            target: root
            function onCurrentFilePathChanged() { editorFlickable.updateHighlighter(); }
        }

        MouseArea {
            anchors.fill: parent
            z: 15
            acceptedButtons: Qt.NoButton

            onWheel: function(wheel) {
                if (wheel.modifiers & Qt.ControlModifier) {
                    if (wheel.angleDelta.y > 0) {
                        root.zoomRequested(1);
                    } else if (wheel.angleDelta.y < 0) {
                        root.zoomRequested(-1);
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

            Row {
                id: contentRow
                anchors.fill: parent
                spacing: 0

                EditorLineGutter {
                    id: lineGutter
                    height: parent.height
                    editor: editor
                    appPalette: root.appPalette
                    diskContent: root.diskContent
                    originalContent: root.originalContent
                    editorFontFamily: root.editorFontFamily
                    editorFontSize: root.editorFontSize
                }

                TextEdit {
                    id: editor
                    z: 2
                    width: editorFlickable.width - lineGutter.width - 12
                    height: Math.max(implicitHeight, editorFlickable.height)
                    topPadding: 10
                    leftPadding: 6
                    bottomPadding: 20
                    color: root.appPalette.textMain
                    font.family: root.editorFontFamily
                    font.pixelSize: root.editorFontSize
                    selectByMouse: true
                    persistentSelection: true
                    focus: true
                    activeFocusOnTab: true
                  //  cursorVisible: activeFocus
                    wrapMode: TextEdit.WrapAnywhere
                    selectionColor: root.appPalette.textSelectionBg
                    selectedTextColor: root.appPalette.textSelectedColor

                    property bool isHandlingSpecialKey: false

                    EditorKeyHandler {
                        id: keyHandler
                        editor: editor
                        multi: multiCaret
                    }

                    Component.onCompleted: {
                        editorFlickable.updateHighlighter();
                        editor.forceActiveFocus();
                        multiCaret.setDocument(editor.textDocument);
                    }

                    MouseArea {
                        id: emptyAreaBelowText
                        anchors.fill: parent
                        z: 0
                        cursorShape: Qt.IBeamCursor
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        enabled: emptyAreaBelowText.mouseY > editor.contentHeight + editor.topPadding

                        onClicked: {
                            editor.forceActiveFocus();
                            editor.cursorPosition = editor.text.length;
                        }
                    }

                    Repeater {
                        model: multiCaret.positions
                        delegate: Rectangle {
                            required property int modelData
                            readonly property rect caretRect: {
                                root.caretTick; editor.width; editor.contentHeight; editor.font.pixelSize;
                                return editor.positionToRectangle(modelData);
                            }
                            x: caretRect.x
                            y: caretRect.y
                            width: 2
                            height: caretRect.height > 0 ? caretRect.height : editor.font.pixelSize + 4
                            color: editor.color
                            visible: editor.activeFocus
                            z: 5
                        }
                    }

                    // Alt+click adds a caret
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedModifiers: Qt.AltModifier
                        onTapped: function(eventPoint) {
                            var clicked = editor.positionAt(eventPoint.position.x, eventPoint.position.y);
                            if (clicked === root.curCaret && root.prevCaret !== root.curCaret)
                                multiCaret.addCursor(root.prevCaret);   // the click moved the main caret; keep the old spot too
                                else if (clicked !== root.curCaret)
                                    multiCaret.addCursor(clicked);
                        }
                    }

                    // A normal click goes back to a single caret
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedModifiers: Qt.NoModifier
                        onTapped: multiCaret.clear()
                    }

                    Keys.onPressed: function(event) {
                        keyHandler.handleKeyPress(event);
                    }

                    onTextChanged: {
                        if (!isProgrammaticChange && !editor.isHandlingSpecialKey) {
                            root.textModified();
                        }
                    }

                    // onCursorRectangleChanged: {
                    //     var curY = cursorRectangle.y;
                    //     var curH = cursorRectangle.height > 0 ? cursorRectangle.height : font.pixelSize + 4;
                    //     var maxY = Math.max(0, editorFlickable.contentHeight - editorFlickable.height);
                    //
                    //     if (curY + curH > editorFlickable.contentY + editorFlickable.height - 30) {
                    //         editorFlickable.contentY = Math.min(maxY, (curY + curH) - editorFlickable.height + 30);
                    //     } else if (curY < editorFlickable.contentY + 10) {
                    //         editorFlickable.contentY = Math.max(0, curY - 10);
                    //     }
                    // }
                }
            }
        }
    }
}
