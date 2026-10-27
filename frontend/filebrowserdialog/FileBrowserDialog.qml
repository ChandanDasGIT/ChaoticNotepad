import QtQuick
import QtQuick.Layouts

// The Open and Save As box: it lists one folder at a time. Walk through the folders, then pick a file (Open)
// or type a file name (Save As). In Open the typed text filters the list.
// Place it as a child of the window in Main.qml (after SettingsDialog, before PromptDialog), not inside a layout:
//     FileBrowserDialog { anchors.fill: parent; onClosed: editor.forceActiveFocus() }
// and start it from the toolbar:
//     onOpenClicked: BrowserController.openFile()
//     onSaveAsClicked: BrowserController.saveFileAs()
//
// What it needs from BrowserController:
//   open                     the box is open
//   title                    "Open file" or "Save as"
//   actionLabel              the text of the main button: "Open" or "Save"
//   shownDirectory           the folder being shown, e.g. "~/projects/"
//   fieldLabel, name         the label and the text of the field ("Filter" / "Name")
//   entries                  list of { name, isDir } (".." comes first)
//   selectedRow              index of the selected entry
//   listHasFocus             draw the selection strongly
//   showHidden               hidden names (starting with ".") are listed
//   emptyMessage             shown instead of the list when it is empty ("" = there are rows)
//   error, hint              one line under the list (the error is red and wins)
//   setVisibleRows(n)        how many rows fit (the wrapper needs it for Page Up / Page Down)
//   keyPressed(key, text, modifiers)   typing, Enter, Esc, arrows, Backspace, Alt+Up ...
//   click(row), activate(), cancel(), goUp(), toggleHidden()
Item {
    id: root

    signal closed()                          // the box was closed: give the keyboard back to the text

    readonly property int rowHeight: 28

    visible: BrowserController.open
    z: 150
    focus: BrowserController.open

    onVisibleChanged: {
        if (visible) forceActiveFocus()
        else root.closed()
    }

    // every key belongs to the box while it is open
    Keys.onPressed: (event) => {
        BrowserController.keyPressed(event.key, event.text, event.modifiers)
        event.accepted = true
    }

    // ---- dimmed background; the box is modal ----
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    // ---- small parts ----
    component IconButton: Item {
        id: b
        property string icon: ""
        property bool on: false
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: b.on ? Qt.alpha(Theme.accent, 0.28) : area.containsMouse ? Theme.hoverBg : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Icon.fontFamily
            font.pixelSize: 13
            color: b.on || area.containsMouse ? Theme.text : Theme.iconDefault
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    component DialogButton: Item {
        id: d
        property string label: ""
        property bool primary: false
        signal clicked()
        implicitWidth: Math.max(88, caption.implicitWidth + 28)
        implicitHeight: 32
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: d.primary ? Theme.accent : area.containsMouse ? Theme.hoverBg : Theme.findFieldBg
            border.width: d.primary ? 0 : 1
            border.color: Theme.findFieldBorder
        }
        Text {
            id: caption
            anchors.centerIn: parent
            text: d.label
            color: d.primary ? "#ffffff" : Theme.text
            font.pixelSize: Theme.uiFontSize + 1
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: d.clicked()
        }
    }

    // ---- the box ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(640, root.width - 32)
        height: Math.min(520, root.height - 32)
        radius: 8
        color: Theme.dialogBg
        border.width: 1
        border.color: Theme.findFieldBorder
        clip: true

        MouseArea { anchors.fill: parent }          // clicks on the box must not reach the dimmed background

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // title
            Text {
                Layout.fillWidth: true
                text: BrowserController.title
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 4
                font.bold: true
            }

            // folder bar: up, the folder, hidden files
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    icon: Icon.chevronUp
                    onClicked: BrowserController.goUp()
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 4
                    color: Theme.findFieldBg
                    border.width: 1
                    border.color: Theme.findFieldBorder

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideLeft            // a long path loses its beginning, not the folder you are in
                        text: BrowserController.shownDirectory
                        color: Theme.text
                        font.pixelSize: Theme.uiFontSize + 1
                    }
                }
                IconButton {
                    icon: Icon.more
                    on: BrowserController.showHidden
                    onClicked: BrowserController.toggleHidden()
                }
            }

            // the text field: filter (Open) or file name (Save As). Typing goes through the box's keys.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 46
                    text: BrowserController.fieldLabel
                    color: Theme.iconDefault
                    font.pixelSize: Theme.uiFontSize + 1
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 4
                    color: Theme.findFieldBg
                    border.width: 1
                    border.color: !BrowserController.listHasFocus || BrowserController.fieldLabel === "Filter"
                                  ? Theme.accent : Theme.findFieldBorder

                    Text {
                        id: fieldText
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        elide: Text.ElideLeft
                        text: BrowserController.name
                        color: Theme.text
                        font.family: Theme.editorFontFamily
                        font.pixelSize: Theme.uiFontSize + 1
                    }
                    Rectangle {                          // the text cursor
                        x: 8 + Math.min(fieldText.contentWidth, fieldText.width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 16
                        color: Theme.text
                        visible: root.visible
                    }
                }
            }

            // the list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: Theme.findFieldBg
                border.width: 1
                border.color: Theme.findFieldBorder
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 1
                    model: BrowserController.entries
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: BrowserController.selectedRow

                    // the wrapper needs to know how many rows fit
                    onHeightChanged: Qt.callLater(list.report)
                    Component.onCompleted: Qt.callLater(list.report)
                    function report() {
                        BrowserController.setVisibleRows(Math.max(1, Math.floor(list.height / root.rowHeight)))
                    }

                    // keep the selected row on screen when the keys move it
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === BrowserController.selectedRow

                        width: list.width
                        height: root.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            color: row.selected
                                   ? (BrowserController.listHasFocus ? Qt.alpha(Theme.accent, 0.45) : Theme.hoverBg)
                                   : rowArea.containsMouse ? Qt.alpha(Theme.hoverBg, 0.5) : "transparent"
                        }
                        Text {
                            x: 10
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.isDir ? Icon.folder : Icon.file
                            font.family: Icon.fontFamily
                            font.pixelSize: 13
                            color: row.modelData.isDir ? Theme.accent : Theme.iconDefault
                        }
                        Text {
                            x: 36
                            width: parent.width - 46
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: Theme.text
                            font.pixelSize: Theme.uiFontSize + 1
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: BrowserController.click(row.index)
                        }
                    }
                }

                Text {                                   // an empty folder, or nothing matches the filter
                    anchors.centerIn: parent
                    visible: BrowserController.emptyMessage !== ""
                    text: BrowserController.emptyMessage
                    color: Theme.iconDefault
                    font.pixelSize: Theme.uiFontSize + 1
                }
            }

            // hint or error
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: BrowserController.error !== "" ? BrowserController.error : BrowserController.hint
                color: BrowserController.error !== "" ? Theme.findError : Theme.iconDefault
                font.pixelSize: Theme.uiFontSize
            }

            // buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }
                DialogButton {
                    label: "Cancel"
                    onClicked: BrowserController.cancel()
                }
                DialogButton {
                    label: BrowserController.actionLabel
                    primary: true
                    onClicked: BrowserController.activate()
                }
            }
        }
    }
}
