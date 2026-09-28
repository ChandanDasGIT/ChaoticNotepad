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
    property string currentFilePath: ""
    property bool isProgrammaticChange: false

    signal textModified()
    signal zoomRequested(int delta)

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
                    }

                    Component.onCompleted: {
                        editorFlickable.updateHighlighter();
                        editor.forceActiveFocus();
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

                    Keys.onPressed: function(event) {
                        keyHandler.handleKeyPress(event);
                    }

                    onTextChanged: {
                        if (!isProgrammaticChange && editor.activeFocus && !editor.isHandlingSpecialKey) {
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
