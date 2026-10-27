import QtQuick

// One tab of the tab bar. It only draws and reports clicks.
// A tab that has unsaved changes shows a dot where the close button is; the dot turns into the
// close button when the mouse is over it.
Item {
    id: root

    property string title: ""
    property bool modified: false
    property bool current: false
    signal clicked()
    signal closeRequested()
    signal dragStarted(real sceneX)          // the mouse took hold of the tab and moved
    signal dragMoved(real sceneX)
    signal dragEnded()

    readonly property bool closeHovered: closeArea.containsMouse
    readonly property bool hovered: tabArea.containsMouse || closeArea.containsMouse
    readonly property bool showDot: root.modified && !root.closeHovered
    readonly property bool showClose: root.current || root.hovered || root.modified

    implicitWidth: Math.max(Theme.tabMinWidth,
                            Math.min(Theme.tabMaxWidth,
                                     titleText.implicitWidth + 2 * Theme.tabPadding + Theme.tabCloseSize))
    implicitHeight: Theme.tabBarHeight

    // ---- background and the blue line on top of the current tab ----
    Rectangle {
        anchors.fill: parent
        color: root.current ? Theme.tabActiveBg : root.hovered ? Theme.tabHoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        visible: root.current
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.tabAccentHeight
        color: Theme.accent
    }

    // ---- click on the tab: select it. Middle click: close it ----
    MouseArea {
        id: tabArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) root.closeRequested()
            else root.clicked()
        }

        // dragging: after a few pixels of movement the tab follows the mouse
        property real pressSceneX: 0
        property bool dragging: false
        onPressed: (mouse) => { pressSceneX = mapToItem(null, mouse.x, 0).x; dragging = false }
        onPositionChanged: (mouse) => {
            if (!pressed || !(pressedButtons & Qt.LeftButton)) return
            const sceneX = mapToItem(null, mouse.x, 0).x
            if (!dragging && Math.abs(sceneX - pressSceneX) > 6) {
                dragging = true
                root.dragStarted(pressSceneX)
            }
            if (dragging) root.dragMoved(sceneX)
        }
        onReleased: { if (dragging) { dragging = false; root.dragEnded() } }
        onCanceled: { if (dragging) { dragging = false; root.dragEnded() } }
    }

    // ---- the file name ----
    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: Theme.tabPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width - 2 * Theme.tabPadding - Theme.tabCloseSize)
        text: root.title
        elide: Text.ElideRight
        font.family: Theme.editorFontFamily
        font.pixelSize: Theme.tabFontSize
        color: root.current ? Theme.text : Theme.textMuted
    }

    // ---- the close button (or the modified dot) ----
    Item {
        id: closeBox
        anchors.right: parent.right
        anchors.rightMargin: Theme.tabPadding - 4
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.tabCloseSize
        height: Theme.tabCloseSize

        Text {
            anchors.centerIn: parent
            visible: root.showClose
            text: root.showDot ? Icon.dot : Icon.close
            font.family: Icon.fontFamily
            font.pixelSize: root.showDot ? 8 : 10
            color: root.closeHovered ? Theme.text : root.showDot ? Theme.textMuted : Theme.textDim
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            enabled: root.showClose
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }
}
