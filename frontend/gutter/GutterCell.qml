import QtQuick

// The gutter part of one row: change mark, fold arrow and line number. It only draws what it is given.
// A cell is either a row of the rows model or a pinned line at the top (sticky scroll).
Item {
    id: root

    property int rowIndex: 0
    property int lineNumber: 0            // 1-based; 0 for the continuation of a wrapped line
    property int fold: 0                  // 0 nothing, 1 can be folded (open), 2 folded
    property int change: 0                // 0 untouched, 1 unsaved, 2 saved
    property bool isCursorLine: false
    property bool foldMarkersVisible: false   // show the fold arrows on rows that can be folded
    property bool opaque: false               // draw our own background (pinned lines are on top of other rows)

    Rectangle {
        visible: root.opaque
        anchors.fill: parent
        color: Theme.gutterBg
    }

    Rectangle {                               // the change mark, on the right edge of the gutter
        visible: root.change > 0
        x: root.width - 3
        width: 3
        height: root.height
        color: root.change === 1 ? Theme.changeUnsaved : Theme.changeSaved
    }

    Text {                                    // the fold arrow
        visible: root.fold !== 0 && (root.fold === 2 || root.foldMarkersVisible)
        x: root.width - Theme.gutterRight - Theme.gutterFold
        y: Math.round((root.height - implicitHeight) / 2)
        width: Theme.gutterFold
        horizontalAlignment: Text.AlignHCenter
        text: root.fold === 2 ? Icon.chevronRight : Icon.chevronDown
        font.family: Icon.fontFamily
        font.pixelSize: 10
        color: Theme.textDim
    }

    Text {                                    // the line number
        visible: root.lineNumber > 0
        x: root.width - Theme.gutterRight - Theme.gutterFold - implicitWidth
        y: Math.round((root.height - implicitHeight) / 2)
        text: root.lineNumber
        font.family: Theme.editorFontFamily
        font.pixelSize: Theme.editorFontSize
        color: root.isCursorLine ? Theme.gutterTextActive : Theme.gutterText
    }
}
