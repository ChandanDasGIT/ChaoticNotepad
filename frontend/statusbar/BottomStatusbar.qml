import QtQuick
import QtQuick.Layouts

// The thin strip above the bottom toolbar. Left: the latest message. Right: facts about the current
// document. It only shows what it is given: the wrapper will set these properties from the engine later.
Rectangle {
    id: root

    property string message: "ready"
    property int line: 1                 // 1-based, as shown to the user
    property int column: 1
    property int selectedChars: 0        // 0 = nothing selected
    property int cursorCount: 1          // more than 1 = multi-cursor
    property string indent: "Spaces: 4"
    property string encoding: "UTF-8"
    property string lineEnding: "LF"
    property string language: "Plain Text"
    property int lines: 1
    property int words: 0
    property int paragraphs: 0

    implicitHeight: Theme.statusBarHeight
    color: Theme.statusBarBg

    // the same look for every piece of text in the bar
    component StatusText: Text {
        color: Theme.textMuted
        font.pixelSize: Theme.statusFontSize
        verticalAlignment: Text.AlignVCenter
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.toolbarMargin
        anchors.rightMargin: Theme.toolbarMargin
        spacing: Theme.statusItemGap

        StatusText {                     // takes all the space that is left, cuts long messages
            Layout.fillWidth: true
            text: root.message
            elide: Text.ElideRight
        }

        StatusText { visible: root.cursorCount > 1;  text: root.cursorCount + " cursors" }
        StatusText { visible: root.selectedChars > 0; text: root.selectedChars + " selected" }
        StatusText { text: "Lines: " + root.lines }
        StatusText { text: "Words: " + root.words }
        StatusText { text: "Paragraphs: " + root.paragraphs }
        StatusText { text: "Ln " + root.line + ", Col " + root.column }
        StatusText { text: root.indent }
        StatusText { text: root.encoding }
        StatusText { text: root.lineEnding }
        StatusText { text: root.language }
    }
}
