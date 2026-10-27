import QtQuick

// One button of the bottom toolbar: an icon glyph and a label. Greys out when `enabled` is false.
Item {
    id: root

    property string icon: ""        // a glyph from Icon.qml, e.g. Icon.save
    property string label: ""
    signal clicked()

    implicitWidth: content.implicitWidth + 2 * Theme.toolbarButtonPadding
    implicitHeight: Theme.bottomBarHeight

    readonly property bool hovered: mouse.containsMouse && root.enabled
    readonly property color iconColor: !root.enabled ? Theme.textDisabled
                                                     : hovered ? Theme.text : Theme.iconDefault
    readonly property color labelColor: !root.enabled ? Theme.textDisabled : Theme.text

    Rectangle {                      // the hover background
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: 4
        color: Theme.hoverBg
        visible: root.hovered
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.toolbarIconGap

        Text {
            width: Theme.toolbarIconSize + 2
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            font.family: Icon.fontFamily
            font.pixelSize: Theme.toolbarIconSize
            color: root.iconColor
        }
        Text {
            text: root.label
            font.pixelSize: Theme.uiFontSize
            color: root.labelColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
