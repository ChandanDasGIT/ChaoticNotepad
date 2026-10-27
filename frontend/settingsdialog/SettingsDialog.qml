import QtQuick
import QtQuick.Layouts

// The settings dialog: a panel over the whole window with a dimmed background.
// Place it as the LAST child of the window in Main.qml (not inside a layout) and open it from the toolbar:
//     SettingsDialog { id: settingsDialog; anchors.fill: parent; onClosed: editor.forceActiveFocus() }
//     BottomToolbar { onSettingsClicked: settingsDialog.open() }
// Esc, the X and a click outside the panel close it.
//
// It also applies the choices to the Theme (font and dark mode), so Main.qml needs nothing else.
//
// What it needs from SettingsController:
//   darkTheme, fontFamily, fontSize, indentWidth, useTabs, autoCloseBrackets, showMinimap
//   setDarkTheme(on), setFontFamily(name), setFontSize(n), setIndentWidth(n), setUseTabs(on),
//   setAutoCloseBrackets(on), setShowMinimap(on)
Item {
    id: root

    signal closed()

    property bool opened: false
    property bool choosingFont: false        // the list of fonts is shown over the settings
    function open()  { choosingFont = false; opened = true; forceActiveFocus() }
    function close() { if (!opened) return; opened = false; choosingFont = false; closed() }

    visible: opened
    z: 100
    focus: opened
    Keys.onEscapePressed: close()

    // ---- the choices are applied to the Theme ----
    Binding { target: Theme; property: "isDark";             value: SettingsController.darkTheme }
    Binding { target: Theme; property: "editorFontFamily"; value: SettingsController.fontFamily }
    Binding { target: Theme; property: "editorFontSize";   value: SettingsController.fontSize }

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

    // ---- the panel ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(480, root.width - 32)
        height: Math.min(content.implicitHeight + header.height + 2 * 16, root.height - 32)
        radius: 8
        color: Theme.dialogBg
        border.width: 1
        border.color: Theme.findFieldBorder
        clip: true

        MouseArea {                                 // clicks and the wheel on the panel must not reach what is behind it
            anchors.fill: parent
            onWheel: (wheel) => wheel.accepted = true
        }

        Item {
            id: header
            anchors.top: parent.top
            width: parent.width
            height: 46

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 20
                text: "Settings"
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 4
                font.bold: true
            }
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.stickyDivider
            }
        }

        Flickable {
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            anchors.topMargin: 8
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 0

                // ---- Appearance ----
                Text {
                    Layout.topMargin: 4
                    text: "APPEARANCE"
                    color: Theme.accent
                    font.pixelSize: Theme.uiFontSize - 1
                    font.bold: true
                    font.letterSpacing: 1
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Dark theme"
                    description: "Turn off for the light theme."
                    SettingsSwitch {
                        checked: SettingsController.darkTheme
                        onToggled: (on) => SettingsController.setDarkTheme(on)
                    }
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Editor font"
                    description: "Any installed font. Monospace fonts look best."
                    Rectangle {                              // shows the font in use; a click opens the list
                        width: 190
                        height: 28
                        radius: 4
                        color: fontArea.containsMouse ? Theme.hoverBg : Theme.findFieldBg
                        border.width: 1
                        border.color: Theme.findFieldBorder

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 8
                            width: parent.width - 30
                            elide: Text.ElideRight
                            text: SettingsController.fontFamily
                            font.family: SettingsController.fontFamily
                            font.pixelSize: Theme.uiFontSize + 1
                            color: Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            text: Icon.chevronRight
                            font.family: Icon.fontFamily
                            font.pixelSize: 10
                            color: Theme.iconDefault
                        }
                        MouseArea {
                            id: fontArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choosingFont = true
                        }
                    }
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Font size"
                    SettingsStepper {
                        from: 8
                        to: 32
                        value: SettingsController.fontSize
                        onValueModified: (v) => SettingsController.setFontSize(v)
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; Layout.preferredHeight: 1; color: Theme.stickyDivider }

                // ---- Editor ----
                Text {
                    Layout.topMargin: 12
                    text: "EDITOR"
                    color: Theme.accent
                    font.pixelSize: Theme.uiFontSize - 1
                    font.bold: true
                    font.letterSpacing: 1
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Indent width"
                    description: "Spaces for each level of indentation."
                    SettingsStepper {
                        from: 1
                        to: 16
                        value: SettingsController.indentWidth
                        onValueModified: (v) => SettingsController.setIndentWidth(v)
                    }
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Indent with tabs"
                    description: "Use a tab character instead of spaces."
                    SettingsSwitch {
                        checked: SettingsController.useTabs
                        onToggled: (on) => SettingsController.setUseTabs(on)
                    }
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Close brackets and quotes"
                    description: "Typing ( [ { or a quote adds the closing one."
                    SettingsSwitch {
                        checked: SettingsController.autoCloseBrackets
                        onToggled: (on) => SettingsController.setAutoCloseBrackets(on)
                    }
                }
                SettingsRow {
                    Layout.fillWidth: true
                    title: "Show minimap"
                    description: "The small picture of the file at the right. Alt+M does the same."
                    SettingsSwitch {
                        checked: SettingsController.showMinimap
                        onToggled: (on) => SettingsController.setShowMinimap(on)
                    }
                }
            }
        }

        // ---- the list of fonts, over everything in the panel ----
        FontListPanel {
            anchors.fill: parent
            visible: root.choosingFont
            current: SettingsController.fontFamily
            onPicked: (name) => {
                SettingsController.setFontFamily(name)
                root.choosingFont = false
                root.forceActiveFocus()
            }
            onCancelled: {
                root.choosingFont = false
                root.forceActiveFocus()
            }
        }
    }
}
