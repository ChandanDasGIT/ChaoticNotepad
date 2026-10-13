import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NotepadQtQuick

Rectangle {
    id: root
    width: 480
    height: replaceRow.visible ? 76 : 38
    color: appPalette ? appPalette.tabBg : "#21252b"
    border.color: appPalette ? appPalette.border : "#30363d"
    border.width: 1
    radius: 6
    clip: true

    required property QtObject appPalette
    required property var targetEditor

    TextSearcher { id: textSearcher }

    property var searchMatches: []
    property int currentSearchIndex: -1

    property bool wholeWord: false

    signal matchSelected(int position)

    function show(withReplace) {
        replaceRow.visible = withReplace;
        visible = true;
        findInput.forceActiveFocus();
        findInput.selectAll();
        updateSearch();
    }

    function hide() {
        visible = false;
        if (targetEditor) {
            targetEditor.deselect();
            targetEditor.forceActiveFocus();
        }
    }

    function updateSearch() {
        if (!targetEditor || findInput.text.length === 0) {
            searchMatches = [];
            currentSearchIndex = -1;
            statusLabel.text = "";
            if (targetEditor) targetEditor.deselect();
            return;
        }

        searchMatches = textSearcher.findAll(targetEditor.text, findInput.text, false, root.wholeWord);

        if (searchMatches && searchMatches.length > 0) {
            if (currentSearchIndex < 0 || currentSearchIndex >= searchMatches.length) {
                jumpTo(0);
            } else {
                jumpTo(currentSearchIndex);
            }
        } else {
            currentSearchIndex = -1;
            statusLabel.text = "0 of 0";
            if (targetEditor) targetEditor.deselect();
        }
    }

    // Updates matches and the "n of m" label without touching selection/caret
    function refreshMatches() {
        if (!targetEditor || findInput.text.length === 0) return;

        searchMatches = textSearcher.findAll(targetEditor.text, findInput.text, false, root.wholeWord);

        if (!searchMatches || searchMatches.length === 0) {
            currentSearchIndex = -1;
            statusLabel.text = "0 of 0";
            return;
        }

        if (currentSearchIndex < 0) currentSearchIndex = 0;
        if (currentSearchIndex >= searchMatches.length) currentSearchIndex = searchMatches.length - 1;
        statusLabel.text = (currentSearchIndex + 1) + " of " + searchMatches.length;
    }

    function jumpTo(index) {
        if (!targetEditor || !searchMatches || searchMatches.length === 0) return;
        currentSearchIndex = (index + searchMatches.length) % searchMatches.length;

        var start = searchMatches[currentSearchIndex];
        var end = start + findInput.text.length;

        targetEditor.cursorPosition = end;
        targetEditor.select(start, end);
        statusLabel.text = (currentSearchIndex + 1) + " of " + searchMatches.length;
        matchSelected(start);
    }

    function findNext() {
        if (!searchMatches || searchMatches.length === 0) return;
        jumpTo(textSearcher.findNext(currentSearchIndex, searchMatches.length));
    }

    function findPrev() {
        if (!searchMatches || searchMatches.length === 0) return;
        jumpTo(textSearcher.findPrev(currentSearchIndex, searchMatches.length));
    }

    function replaceCurrent() {
        if (!targetEditor || currentSearchIndex === -1 || !searchMatches || searchMatches.length === 0) return;
        var start = searchMatches[currentSearchIndex];
        textSearcher.replaceRange(targetEditor.textDocument, start, findInput.text.length, replaceInput.text);
        updateSearch();
    }

    function replaceAll() {
        if (!targetEditor || findInput.text.length === 0) return;
        var count = textSearcher.replaceAllInDocument(targetEditor.textDocument,
        findInput.text, replaceInput.text, false, root.wholeWord);
        if (count > 0) updateSearch();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: replaceRow.visible ? "▼" : "▶"
                color: toggleHover.hovered ? root.appPalette.iconHover : root.appPalette.textMuted
                font.pixelSize: 10
                Layout.alignment: Qt.AlignVCenter
                HoverHandler { id: toggleHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: replaceRow.visible = !replaceRow.visible }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 26
                color: root.appPalette.editorBg
                border.color: findInput.activeFocus ? root.appPalette.highlight : root.appPalette.border
                radius: 4

                TextInput {
                    id: findInput
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.appPalette.textMain
                    font.family: "Monospace"
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: root.updateSearch()
                    onAccepted: root.findNext()

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.hide();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ShiftModifier)) {
                            root.findPrev();
                        event.accepted = true;
                            }
                    }
                }
            }

            Button {
                id: wordBtn
                text: "W"
                checkable: true
                checked: root.wholeWord
                implicitWidth: 24
                implicitHeight: 24

                onToggled: { root.wholeWord = checked; root.updateSearch(); }

                ToolTip {
                    id: wordTip
                    visible: wordBtn.hovered
                    text: "Whole word"

                    contentItem: Text {
                        text: wordTip.text
                        font.pixelSize: 11
                        color: root.appPalette.isDark ? "#ffffff" : wordTip.palette.toolTipText
                    }

                    background: Rectangle {
                        color: root.appPalette.isDark ? "#4b5263" : wordTip.palette.toolTipBase
                        border.color: root.appPalette.isDark ? "#5c6370" : wordTip.palette.dark
                        radius: 3
                    }
                }

                contentItem: Text {
                    text: wordBtn.text
                    color: wordBtn.checked ? "#ffffff" : root.appPalette.textMain
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: wordBtn.checked ? root.appPalette.highlight
                    : (wordBtn.hovered ? root.appPalette.editorBg : "transparent")
                    border.color: root.appPalette.border
                    radius: 3
                }
            }

            Text {
                id: statusLabel
                color: (root.searchMatches && root.searchMatches.length > 0) ? root.appPalette.textMuted : root.appPalette.danger
                font.family: "Monospace"
                font.pixelSize: 11
                Layout.preferredWidth: 65
                horizontalAlignment: Text.AlignRight
            }

            Button {
                id: prevBtn
                text: "↑"
                implicitWidth: 24
                implicitHeight: 24
                contentItem: Text {
                    text: parent.text
                    color: root.appPalette.textMain
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: prevBtn.down ? root.appPalette.highlight
                    : (prevBtn.hovered ? root.appPalette.hoverBg : "transparent")
                    border.color: root.appPalette.border
                    radius: 3
                }
                onClicked: root.findPrev()
            }

            Button {
                id: nextBtn
                text: "↓"
                implicitWidth: 24
                implicitHeight: 24
                contentItem: Text {
                    text: parent.text
                    color: root.appPalette.textMain
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: nextBtn.down ? root.appPalette.highlight : (nextBtn.hovered ? root.appPalette.hoverBg : "transparent")
                    border.color: root.appPalette.border
                    radius: 3
                }
                onClicked: root.findNext()
            }

            Text {
                text: "×"
                color: closeHover.hovered ? root.appPalette.iconHover : root.appPalette.textMuted
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.hide() }
            }
        }

        RowLayout {
            id: replaceRow
            Layout.fillWidth: true
            spacing: 6
            visible: false

            Item { width: 10 }

            Rectangle {
                Layout.fillWidth: true
                height: 26
                color: root.appPalette.editorBg
                border.color: replaceInput.activeFocus ? root.appPalette.highlight : root.appPalette.border
                radius: 4

                TextInput {
                    id: replaceInput
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.appPalette.textMain
                    font.family: "Monospace"
                    font.pixelSize: 12
                    selectByMouse: true
                    onAccepted: root.replaceCurrent()
                    Keys.onEscapePressed: root.hide()
                }
            }

            Button {
                id: repBtn
                text: "Replace"
                implicitHeight: 24
                contentItem: Text {
                    text: parent.text
                    color: root.appPalette.textMain
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: repBtn.down ? root.appPalette.highlight
                    : (repBtn.hovered ? root.appPalette.hoverBg : "transparent")
                    border.color: root.appPalette.border
                    radius: 3
                }
                onClicked: root.replaceCurrent()
            }

            Button {
                id: repAllBtn
                text: "All"
                implicitHeight: 24
                contentItem: Text {
                    text: parent.text
                    color: root.appPalette.textMain
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: repAllBtn.down ? root.appPalette.highlight : (repAllBtn.hovered ? root.appPalette.hoverBg : "transparent")
                    border.color: root.appPalette.border
                    radius: 3
                }
                onClicked: root.replaceAll()
            }
        }
    }
}
