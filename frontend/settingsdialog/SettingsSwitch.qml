import QtQuick

// An on/off switch. It does not change itself: it tells you the new value and you set `checked`.
//     SettingsSwitch { checked: SettingsController.darkTheme; onToggled: (on) => SettingsController.setDarkTheme(on) }
Item {
    id: root

    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.switchOff
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
