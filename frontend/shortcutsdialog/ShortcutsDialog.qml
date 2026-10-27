import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The shortcuts dialog: a panel over the whole window with every shortcut. Most of them can be changed:
// click the keys of a shortcut, then press the new keys. Esc cancels. "Restore defaults" puts them all back.
// Place it as the LAST child of the window in Main.qml (not inside a layout) and open it from the toolbar:
//     ShortcutsDialog { id: shortcutsDialog; anchors.fill: parent; onClosed: editor.forceActiveFocus() }
//     BottomToolbar { onShortcutsClicked: shortcutsDialog.open() }
// Esc (when no shortcut is waiting for keys), the X and a click outside the panel close it.
//
// What it needs from ShortcutsController:
//   sections       [ { title, items: [ { id, what, fixed, changed, keys, defaultKeys } ] } ]
//                  keys: a list of ways to do it, each way a list of key names ["Ctrl", "Shift", "S"]
//   anyChanged     true when some shortcut is not at its built-in key
//   setShortcut(id, key, modifiers)   returns "" or the reason the keys were refused
//   reset(id), resetAll()
Item {
    id: root

    signal closed()

    property bool opened: false
    property string listeningId: ""          // the shortcut that is waiting for new keys ("" = none)
    property string errorId: ""              // the shortcut that refused the last keys, and why
    property string errorText: ""

    function open() {
        listeningId = ""
        errorId = ""
        opened = true
        forceActiveFocus()
    }
    function close() {
        if (!opened) return
        opened = false
        listeningId = ""
        errorId = ""
        closed()
    }
    function listenTo(id) {
        errorId = ""
        listeningId = id
        forceActiveFocus()
    }

    visible: opened
    z: 100
    focus: opened

    // While a shortcut is waiting, every key goes to it; Esc cancels. Otherwise Esc closes the dialog.
    Keys.onPressed: (event) => {
        if (root.listeningId === "") {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            return
        }
        event.accepted = true
        switch (event.key) {
        case Qt.Key_Control: case Qt.Key_Alt: case Qt.Key_Shift: case Qt.Key_Meta: case Qt.Key_AltGr:
            return                                       // only a modifier so far: wait for the real key
        case Qt.Key_Escape:
            root.listeningId = ""
            return
        }
        const id = root.listeningId
        const reason = ShortcutsController.setShortcut(id, event.key, event.modifiers)
        root.listeningId = ""
        if (reason !== "") {
            root.errorId = id
            root.errorText = reason
        }
    }

    // a changed list would start again from the top: put it back where it was
    Connections {
        target: ShortcutsController
        function onChanged() {
            const y = list.contentY
            Qt.callLater(() => { list.contentY = y })
        }
    }

    // ---- dimmed background; a click on it closes the dialog ----
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        onWheel: (wheel) => wheel.accepted = true        // the wheel must not scroll the text under the dialog
    }

    // a key like Ctrl or O, drawn as a small key cap
    component KeyCap: Rectangle {
        property string label: ""
        implicitWidth: Math.max(22, caption.implicitWidth + 12)
        implicitHeight: 22
        radius: 4
        color: Theme.findFieldBg
        border.width: 1
        border.color: Theme.findFieldBorder
        Text {
            id: caption
            anchors.centerIn: parent
            text: parent.label
            color: Theme.text
            font.pixelSize: Theme.uiFontSize
        }
    }

    // ---- the panel ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(620, root.width - 32)
        height: Math.min(640, root.height - 32)
        radius: 8
        color: Theme.dialogBg
        border.width: 1
        border.color: Theme.findFieldBorder
        clip: true

        MouseArea {                                 // clicks and the wheel on the panel must not reach what is behind it
            anchors.fill: parent
            onWheel: (wheel) => wheel.accepted = true
        }

        // ---- title, hint, close button ----
        Item {
            id: header
            anchors.top: parent.top
            width: parent.width
            height: 46 + hint.height

            Text {
                x: 20
                y: 12
                text: "Keyboard shortcuts"
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 4
                font.bold: true
            }
            Item {
                anchors.right: parent.right
                y: 9
                anchors.rightMargin: 10
                width: 28
                height: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.hoverBg
                    visible: closeArea.containsMouse
                }
                Text {
                    anchors.centerIn: parent
                    text: Icon.close
                    font.family: Icon.fontFamily
                    font.pixelSize: 13
                    color: closeArea.containsMouse ? Theme.text : Theme.iconDefault
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
            Text {
                id: hint
                x: 20
                y: 40
                width: parent.width - 40
                height: implicitHeight + 10
                wrapMode: Text.WordWrap
                color: Theme.textMuted
                font.pixelSize: Theme.uiFontSize
                text: "Click the keys of a shortcut, then press the new keys. Use Ctrl or Alt together with a key. " +
                      "The Meta (Super / Windows) key cannot be used. Esc cancels. Shortcuts without a button are fixed."
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.stickyDivider
            }
        }

        // ---- the list ----
        ListView {
            id: list
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            topMargin: 8
            bottomMargin: 8
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: ShortcutsController.sections

            ScrollBar.vertical: ScrollBar {
                id: listScroll
                policy: ScrollBar.AsNeeded
                width: 10
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: listScroll.pressed ? Theme.scrollbarHandlePressed
                         : listScroll.hovered ? Theme.scrollbarHandleHover : Theme.scrollbarHandle
                }
                background: Item {}
            }

            delegate: Column {
                id: section
                required property var modelData
                width: list.width - 14
                spacing: 2

                Text {                                   // the heading of the group
                    topPadding: 8
                    bottomPadding: 2
                    text: section.modelData.title
                    color: Theme.accent
                    font.pixelSize: Theme.uiFontSize
                    font.bold: true
                }

                Repeater {
                    model: section.modelData.items

                    Item {
                        id: entry
                        required property var modelData
                        readonly property bool listening: root.listeningId !== "" && root.listeningId === modelData.id
                        readonly property bool failed: root.errorId !== "" && root.errorId === modelData.id

                        width: section.width
                        height: Math.max(28, keysColumn.implicitHeight + 6) + (failed ? errorLabel.implicitHeight + 2 : 0)

                        Text {                           // what it does
                            anchors.left: parent.left
                            anchors.right: keysSide.left
                            anchors.rightMargin: 12
                            y: 4
                            height: Math.max(28, keysColumn.implicitHeight + 6) - 8
                            verticalAlignment: Text.AlignVCenter
                            text: entry.modelData.what
                            wrapMode: Text.WordWrap
                            color: Theme.textMuted
                            font.pixelSize: Theme.uiFontSize + 1
                        }

                        // the keys, and the small button that gives the shortcut its built-in keys back
                        Row {
                            id: keysSide
                            anchors.right: parent.right
                            y: 3
                            spacing: 6

                            Item {                       // reset button (only for a changed shortcut)
                                width: 24
                                height: 24
                                visible: !entry.modelData.fixed && entry.modelData.changed
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Theme.hoverBg
                                    visible: resetArea.containsMouse
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Icon.undo
                                    font.family: Icon.fontFamily
                                    font.pixelSize: 11
                                    color: resetArea.containsMouse ? Theme.text : Theme.iconDefault
                                }
                                MouseArea {
                                    id: resetArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.errorId = ""
                                        ShortcutsController.reset(entry.modelData.id)
                                    }
                                }
                            }

                            Rectangle {                  // the keys; a click waits for new ones
                                id: keysBox
                                width: Math.max(keysColumn.implicitWidth, 150) + 12
                                height: Math.max(28, keysColumn.implicitHeight + 6) - 4
                                radius: 5
                                color: !entry.modelData.fixed && keysArea.containsMouse ? Theme.hoverBg : "transparent"
                                border.width: entry.listening || entry.failed ? 1 : 0
                                border.color: entry.failed ? Theme.findError : Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    visible: entry.listening
                                    text: "Press the new keys…"
                                    color: Theme.accent
                                    font.pixelSize: Theme.uiFontSize
                                }

                                Column {
                                    id: keysColumn
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    visible: !entry.listening

                                    Repeater {
                                        model: entry.modelData.keys

                                        Row {
                                            id: way
                                            required property var modelData        // ["Ctrl", "S"]
                                            anchors.right: parent.right
                                            spacing: 4

                                            Repeater {
                                                model: way.modelData
                                                KeyCap {
                                                    required property string modelData
                                                    label: modelData
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: keysArea
                                    anchors.fill: parent
                                    hoverEnabled: !entry.modelData.fixed
                                    enabled: !entry.modelData.fixed
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.listenTo(entry.modelData.id)
                                }
                            }
                        }

                        Text {                           // why the keys were refused
                            id: errorLabel
                            visible: entry.failed
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.bottom: parent.bottom
                            text: root.errorText
                            color: Theme.findError
                            font.pixelSize: Theme.uiFontSize
                        }
                    }
                }
            }
        }

        // ---- the bottom strip ----
        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: 48

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Theme.stickyDivider
            }
            Rectangle {                                  // "Restore defaults"
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: restoreText.implicitWidth + 28
                height: 30
                radius: 5
                opacity: ShortcutsController.anyChanged ? 1 : 0.4
                color: restoreArea.containsMouse && ShortcutsController.anyChanged ? Theme.hoverBg : Theme.findFieldBg
                border.width: 1
                border.color: Theme.findFieldBorder

                Text {
                    id: restoreText
                    anchors.centerIn: parent
                    text: "Restore defaults"
                    color: Theme.text
                    font.pixelSize: Theme.uiFontSize + 1
                }
                MouseArea {
                    id: restoreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: ShortcutsController.anyChanged
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.listeningId = ""
                        root.errorId = ""
                        ShortcutsController.resetAll()
                    }
                }
            }
        }
    }
}
