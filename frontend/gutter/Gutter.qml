import QtQuick

// The gutter: line numbers, fold arrows and change marks, scrolled together with the text.
// It lists the same rows as the text area (GutterController.rows) and follows its scroll position.
// Place it next to CodeEditor and connect the two in Main.qml:
//     Gutter { contentY: editor.contentY; cellWidth: editor.cellWidth; onScrolled: (dy) => editor.scrollBy(dy) }
// A click on a fold arrow folds or unfolds; a click on a pinned line number jumps to that line.
// What it needs from GutterController: rows, sticky, gutterDigits, toggleFold(row), stickyClicked(index).
// (The roles it reads from each row are lineNumber, fold, change and isCursorLine.)
Item {
    id: root

    property real contentY: 0                 // the scroll position of the text area, in pixels
    property real rowHeight: Theme.editorLineHeight
    property real cellWidth: 10               // the width of one character of the editor font

    signal scrolled(real dy)                  // the wheel turned over the gutter: scroll the text by dy pixels

    readonly property int digits: Math.max(2, GutterController.gutterDigits)
    readonly property real stickyHeight: stickyColumn.height

    // wide enough for the largest line number, plus room for the fold arrow
    implicitWidth: Math.ceil(digits * cellWidth) + Theme.gutterLeft + Theme.gutterFold + Theme.gutterRight
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Theme.gutterBg
    }

    ListView {
        id: list
        anchors.fill: parent
        model: GutterController.rows
        interactive: false                    // it only follows the text area
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: GutterCell {
            required property var model
            required property int index

            width: list.width
            height: root.rowHeight
            foldMarkersVisible: mouse.containsMouse

            rowIndex: index
            lineNumber: model.lineNumber
            fold: model.fold
            change: model.change
            isCursorLine: model.isCursorLine
        }
    }
    Binding {                                 // stays in step with the text area, also after the model changes
        target: list
        property: "contentY"
        value: root.contentY
    }

    // ---- the line numbers of the pinned lines ----
    Column {
        id: stickyColumn
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.width

        Repeater {
            model: GutterController.sticky
            GutterCell {
                required property var modelData
                width: stickyColumn.width
                height: root.rowHeight
                opaque: true
                lineNumber: modelData.lineNumber
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y
                                                 : event.angleDelta.y / 120 * Theme.wheelRows * root.rowHeight
            root.scrolled(-dy)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => {
            if (m.y < root.stickyHeight) {                       // a pinned line number
                GutterController.stickyClicked(Math.floor(m.y / root.rowHeight))
                return
            }
            const item = list.itemAt(m.x, m.y + root.contentY)   // the fold arrow
            if (item && item.fold !== 0)
                GutterController.toggleFold(item.rowIndex)
        }
    }
}
