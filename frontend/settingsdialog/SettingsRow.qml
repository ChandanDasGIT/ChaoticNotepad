import QtQuick
import QtQuick.Layouts

// One line of the settings dialog: a title and a short explanation on the left, the control on the right.
//     SettingsRow { title: "Font size"; description: "..."; SettingsStepper { ... } }
Item {
    id: root

    property string title: ""
    property string description: ""
    default property alias control: controlSlot.data    // the control goes here

    implicitHeight: Math.max(texts.implicitHeight, controlSlot.implicitHeight) + 2 * 10

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 16

        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 1
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                color: Theme.iconDefault
                font.pixelSize: Theme.uiFontSize - 1
                wrapMode: Text.WordWrap
            }
        }

        Row {
            id: controlSlot
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
        }
    }
}
