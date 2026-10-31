import QtQuick
import QtQuick.Controls

// The Keyboard shortcuts page of the settings: every shortcut, most of them can be changed.
// Click the keys of a shortcut, then press the new keys. Esc cancels. "Restore defaults" puts them all back.
// Keys it does not use (Esc when no shortcut is waiting for keys) go on to SettingsDialog.
//
// What it needs from ShortcutsController:
//   sections       [ { title, items: [ { id, what, fixed, changed, keys, defaultKeys } ] } ]
//                  keys: a list of ways to do it, each way a list of key names ["Ctrl", "Shift", "S"]
//   anyChanged     true when some shortcut is not at its built-in key
//   setShortcut(id, key, modifiers)   returns "" or the reason the keys were refused
//   reset(id), resetAll()
Item {
    id: root

    property string listeningId: ""          // the shortcut that is waiting for new keys ("" = none)
    property string errorId: ""              // the shortcut that refused the last keys, and why
    property string errorText: ""

    function listenTo(id) {
        errorId = ""
        listeningId = id
        forceActiveFocus()
    }

    // nothing stays half done when the page is left
    onVisibleChanged: {
        listeningId = ""
        errorId = ""
    }

    // While a shortcut is waiting, every key goes to it; Esc cancels.
    Keys.onPressed: (event) => {
        if (root.listeningId === "") return
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

    // ---- title and hint ----
    Item {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: hint.visible ? hint.y + hint.height : 32

        Text {
            x: 16
            y: 12
            text: "KEYBOARD SHORTCUTS"
            color: Theme.accent
            font.pixelSize: Theme.uiFontSize - 1
            font.bold: true
            font.letterSpacing: 1
        }
        Text {
            id: hint
            visible: root.height >= 320              // a small window keeps its room for the list
            x: 16
            y: 32
            width: parent.width - 32
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
        anchors.leftMargin: 16
        anchors.rightMargin: 6
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
                    readonly property real lineHeight: Math.max(28, keysColumn.implicitHeight + 6, whatText.implicitHeight + 8)

                    width: section.width
                    height: lineHeight + (failed ? errorLabel.implicitHeight + 2 : 0)

                    Text {                           // what it does
                        id: whatText
                        anchors.left: parent.left
                        anchors.right: keysSide.left
                        anchors.rightMargin: 6
                        y: 4
                        height: entry.lineHeight - 8
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
            anchors.rightMargin: 16
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
