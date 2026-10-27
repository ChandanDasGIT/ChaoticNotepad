import QtQuick

// The strip of tabs at the top of the window, with a "+" button at the right end.
// `model` is any list model with the roles `title` (string) and `modified` (bool): a ListModel for now,
// the engine wrapper later. When there are more tabs than fit, the strip scrolls with the mouse wheel,
// and it scrolls by itself to keep the current tab in view.
// A tab can be dragged left and right: the other tabs slide out of the way, and tabMoveRequested(from, to)
// is sent each time the tab passes another one.
Rectangle {
    id: root

    property var model
    property int currentIndex: 0

    signal tabClicked(int index)
    signal tabCloseRequested(int index)
    signal newTabRequested()
    signal tabMoveRequested(int from, int to)

    // ---- dragging a tab ----
    property int dragIndex: -1                // the tab that is being dragged (-1 = none)
    property real dragGrab: 0                 // where inside the tab the mouse took hold of it
    property real dragLeft: 0                 // where the left edge of the dragged tab is, in the strip

    function beginDrag(index, sceneX, tab) {
        dragGrab = sceneX - tab.mapToItem(null, 0, 0).x
        dragLeft = tab.x
        dragIndex = index
    }

    // the mouse moved to this x (in window coordinates): follow it, and swap places with a tab it passed
    function dragTo(sceneX) {
        if (dragIndex < 0) return
        dragLeft = sceneX - strip.mapToItem(null, 0, 0).x + strip.contentX - dragGrab
        const dragged = repeater.itemAt(dragIndex)
        if (!dragged) return
        const center = dragLeft + dragged.width / 2
        let x = 0
        let target = repeater.count - 1
        for (let i = 0; i < repeater.count; ++i) {            // the place whose stretch of the strip holds the centre
            const item = repeater.itemAt(i)
            if (!item) continue
            if (center < x + item.width) { target = i; break }
            x += item.width
        }
        if (target !== dragIndex) {
            const from = dragIndex
            dragIndex = target
            root.tabMoveRequested(from, target)
        }
    }

    function endDrag() { dragIndex = -1 }

    implicitHeight: Theme.tabBarHeight
    color: Theme.tabBarBg

    // scrolls the strip just enough to show the current tab completely
    function revealCurrent() {
        const item = repeater.itemAt(root.currentIndex)
        if (!item) return
        if (item.x < strip.contentX) strip.contentX = item.x
        else if (item.x + item.width > strip.contentX + strip.width)
            strip.contentX = item.x + item.width - strip.width
    }
    onCurrentIndexChanged: Qt.callLater(revealCurrent)

    Flickable {
        id: strip
        anchors.left: parent.left
        anchors.right: addButton.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentWidth: row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: false                    // the mouse drags tabs here; the wheel scrolls the strip
        clip: true

        Row {
            id: row
            height: strip.height

            // the tabs slide when another tab is dragged past them, and a new tab fades in
            move: Transition { NumberAnimation { properties: "x"; duration: 160; easing.type: Easing.OutCubic } }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }

            Repeater {
                id: repeater
                model: root.model
                onItemAdded: Qt.callLater(root.revealCurrent)

                delegate: DocumentTab {
                    id: tab
                    required property var model
                    required property int index

                    height: row.height
                    title: model.title
                    modified: model.modified
                    current: index === root.currentIndex
                    onClicked: root.tabClicked(index)
                    onCloseRequested: root.tabCloseRequested(index)

                    // while dragged the tab follows the mouse; when let go it slides into its place
                    readonly property bool beingDragged: root.dragIndex === index
                    property real settle: 0
                    z: beingDragged || settleAnimation.running ? 10 : 0
                    opacity: beingDragged ? 0.92 : 1
                    transform: Translate { x: tab.beingDragged ? root.dragLeft - tab.x : tab.settle }
                    NumberAnimation { id: settleAnimation; target: tab; property: "settle"; to: 0; duration: 140; easing.type: Easing.OutCubic }

                    onDragStarted: (sceneX) => {
                        if (!tab.current) root.tabClicked(index)
                        root.beginDrag(index, sceneX, tab)
                    }
                    onDragMoved: (sceneX) => root.dragTo(sceneX)
                    onDragEnded: {
                        tab.settle = root.dragLeft - tab.x
                        root.endDrag()
                        settleAnimation.restart()
                    }
                }
            }
        }

        // the mouse wheel moves the strip sideways
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                const most = Math.max(0, strip.contentWidth - strip.width)
                strip.contentX = Math.max(0, Math.min(most, strip.contentX - d))
            }
        }
    }

    // ---- the "+" button ----
    Item {
        id: addButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.addTabWidth

        Text {
            anchors.centerIn: parent
            text: Icon.add
            font.family: Icon.fontFamily
            font.pixelSize: 12
            color: addArea.containsMouse ? Theme.text : Theme.textDim
        }
        MouseArea {
            id: addArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.newTabRequested()
        }
    }

    // the thin line under the whole bar
    Rectangle {
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
    }
}
