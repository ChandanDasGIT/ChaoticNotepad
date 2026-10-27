import QtQuick

// A number with a minus and a plus button. It tells you the new value; you set `value`.
//     SettingsStepper { from: 8; to: 32; value: SettingsController.fontSize; onValueModified: (v) => SettingsController.setFontSize(v) }
Row {
    id: root

    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    signal valueModified(int newValue)

    spacing: 4

    component StepButton: Item {
        id: b
        property string icon: ""
        property bool active: true
        signal clicked()
        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: area.containsMouse && b.active ? Theme.hoverBg : Theme.findFieldBg
            border.width: 1
            border.color: Theme.findFieldBorder
        }
        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Icon.fontFamily
            font.pixelSize: 11
            color: b.active ? Theme.text : Theme.textDisabled
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: b.active
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    StepButton {
        icon: Icon.remove
        active: root.value > root.from
        onClicked: root.valueModified(Math.max(root.from, root.value - root.step))
    }

    Text {
        width: 36
        height: 26
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.value
        color: Theme.text
        font.pixelSize: Theme.uiFontSize + 1
    }

    StepButton {
        icon: Icon.add
        active: root.value < root.to
        onClicked: root.valueModified(Math.min(root.to, root.value + root.step))
    }
}
