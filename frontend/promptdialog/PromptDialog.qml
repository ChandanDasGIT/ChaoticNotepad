import QtQuick
import QtQuick.Layouts

// The box that asks a question with two or three buttons: "Unsaved changes" (when closing a tab or quitting),
// "File changed on disk", and the save-conflict question. The engine decides what it says and which button
// is selected; this only draws it and passes the keys and clicks back.
// Place it as the LAST child of the window in Main.qml (after SettingsDialog), not inside a layout:
//     PromptDialog { anchors.fill: parent; onClosed: editor.forceActiveFocus() }
//
// What it needs from DialogController:
//   active                  the box is open
//   title, lines, buttons   the texts (lines is a list of strings; an empty string is a gap)
//   selectedButton          index of the button Enter would choose
//   keyPressed(key, text, modifiers)   Esc, Enter, arrows, Tab, and the first letter of a button
//   clickButton(index)
Item {
    id: root

    signal closed()                          // the box was answered: give the keyboard back to the text

    visible: DialogController.active
    z: 200
    focus: DialogController.active

    onVisibleChanged: {
        if (visible) forceActiveFocus()
        else root.closed()
    }

    // every key belongs to the box while it is open
    Keys.onPressed: (event) => {
        DialogController.keyPressed(event.key, event.text, event.modifiers)
        event.accepted = true
    }

    // ---- dimmed background; the box is modal, so clicks on it do nothing ----
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    // ---- the box ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(460, root.width - 32)
        height: body.implicitHeight + 2 * 20
        radius: 8
        color: Theme.dialogBg
        border.width: 1
        border.color: Theme.findFieldBorder

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: DialogController.title
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 4
                font.bold: true
                elide: Text.ElideRight
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: DialogController.lines
                    Text {
                        required property string modelData
                        width: parent.width
                        height: modelData === "" ? 8 : implicitHeight
                        text: modelData
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: Theme.iconDefault
                        font.pixelSize: Theme.uiFontSize + 1
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8

                Item { Layout.fillWidth: true }          // pushes the buttons to the right

                Repeater {
                    model: DialogController.buttons
                    Item {
                        id: button
                        required property string modelData
                        required property int index
                        readonly property bool selected: index === DialogController.selectedButton
                        readonly property bool destructive: /^don.?t save/i.test(modelData)    // "Don't save" is drawn in red

                        implicitWidth: Math.max(88, label.implicitWidth + 28)
                        implicitHeight: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: button.selected ? (button.destructive ? Theme.danger : Theme.accent)
                                 : area.containsMouse ? (button.destructive ? Qt.alpha(Theme.danger, 0.18) : Theme.hoverBg)
                                 : Theme.findFieldBg
                            border.width: button.selected ? 0 : 1
                            border.color: button.destructive ? Theme.danger : Theme.findFieldBorder
                        }
                        Text {
                            id: label
                            anchors.centerIn: parent
                            textFormat: Text.StyledText      // the first letter is underlined: it picks the button
                            text: button.modelData.length > 0
                                  ? "<u>" + button.modelData.charAt(0) + "</u>" + button.modelData.slice(1)
                                  : ""
                            color: button.selected ? "#ffffff" : button.destructive ? Theme.danger : Theme.text
                            font.pixelSize: Theme.uiFontSize + 1
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DialogController.clickButton(button.index)
                        }
                    }
                }
            }
        }
    }
}
