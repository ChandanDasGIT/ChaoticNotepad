import QtQuick

// The minimap: a small picture of the whole file with the part on screen shaded.
// A thin strip on the left shows edited lines (red = unsaved, green = saved), a thin strip on the right
// shows the cursor, the selection and find matches. Click or drag to scroll the text.
// Place it at the right of CodeEditor and connect the wheel in Main.qml:
//     Minimap { Layout.fillHeight: true; onScrolled: (dy) => editor.scrollBy(dy) }
//
// What it needs from MinimapController:
//   shown                      true when the minimap is switched on (Alt+M)
//   pictureColumns, pictureRows  the size of the picture in minimap pixels
//   (the picture itself is drawn by MinimapPicture, which reads the minimap from the wrapper)
//   viewportTop, viewportRows  the shaded rectangle, in minimap pixel rows
//   marks                      a list of { row, edit, find } for the rows that have something to show:
//                              edit 0 none, 1 unsaved, 2 saved;  find 0 none, 1 selection, 2 cursor, 3 match, 4 current match
//   setSize(columns, rows)     tells the wrapper how many minimap pixels fit
//   setPalette(colors)         the colour of each syntax token number, as a list
//   pressed(row), dragged(row), released()   the mouse, in minimap pixel rows
Item {
    id: root

    signal scrolled(real dy)                  // the wheel turned over the minimap: scroll the text by dy pixels

    readonly property int pixel: Theme.minimapPixel       // screen pixels per minimap pixel
    readonly property int strip: Theme.minimapStrip       // width of each of the two mark strips
    readonly property int pictureWidth: Math.max(0, width - 2 * strip)

    // each row of the picture is stretched so the picture fills the column (up to 4 screen pixels per row)
    readonly property real rowHeight: MinimapController.pictureRows > 0
                                      ? Math.min(4, root.height / MinimapController.pictureRows) : root.pixel

    implicitWidth: Theme.minimapWidth
    visible: MinimapController.shown
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Theme.minimapBg
    }

    // ---- the part of the text that is on screen ----
    Rectangle {
        x: 0
        y: MinimapController.viewportTop * root.rowHeight
        width: root.width
        height: Math.max(root.pixel, MinimapController.viewportRows * root.rowHeight)
        color: Theme.minimapViewport
    }

    // ---- the picture: one small square for each cell of the minimap ----
    MinimapPicture {
        x: root.strip
        y: 0
        width: MinimapController.pictureColumns * root.pixel
        height: MinimapController.pictureRows * root.rowHeight
        pixel: root.pixel
    }

    // ---- the marks ----
    Repeater {
        model: MinimapController.marks
        Item {
            required property var modelData
            y: modelData.row * root.rowHeight
            width: root.width
            height: Math.max(root.rowHeight, 2)

            Rectangle {                           // edited line
                visible: modelData.edit !== 0
                x: 0
                width: root.strip - 1
                height: parent.height
                color: modelData.edit === 1 ? Theme.changeUnsaved : Theme.changeSaved
            }
            Rectangle {                           // selection, cursor, find match
                visible: modelData.find !== 0
                x: root.width - root.strip + 1
                width: root.strip - 1
                height: parent.height
                color: modelData.find === 4 ? Theme.minimapFindCurrent
                     : modelData.find === 3 ? Theme.minimapFind
                     : modelData.find === 2 ? Theme.minimapCursor
                     : Theme.minimapSelection
            }
        }
    }

    // ---- tell the wrapper how much room there is, and the syntax colours ----
    function report() {
        MinimapController.setSize(Math.floor(root.pictureWidth / root.pixel), Math.floor(root.height / root.pixel))
    }
    onPictureWidthChanged: Qt.callLater(report)
    onHeightChanged: Qt.callLater(report)

    function sendPalette() {
        const colors = []
        for (let kind = 0; kind <= 14; ++kind)
            colors.push(Theme.syntaxColor(kind))
        MinimapController.setPalette(colors)
    }
    Component.onCompleted: {
        sendPalette()
        Qt.callLater(report)
    }
    Connections {                             // dark / light changed: send the new syntax colours
        target: Theme
        function onIsDarkChanged() { root.sendPalette() }
    }

    // ---- mouse ----
    function rowAt(y) {
        return Math.max(0, Math.floor(y / root.rowHeight))
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => MinimapController.pressed(root.rowAt(m.y))
        onPositionChanged: (m) => { if (pressed) MinimapController.dragged(root.rowAt(m.y)) }
        onReleased: MinimapController.released()
        onCanceled: MinimapController.released()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y
                                                 : event.angleDelta.y / 120 * Theme.wheelRows * Theme.editorLineHeight
            root.scrolled(-dy)
        }
    }
}
