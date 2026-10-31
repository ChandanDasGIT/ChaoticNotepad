import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The settings dialog: a panel over the whole window with a dimmed background. The sidebar picks a page:
// Appearance, Editor, Keyboard shortcuts (ShortcutsPage) and About.
// Place it as the LAST child of the window in Main.qml (not inside a layout) and open it from the toolbar:
//     SettingsDialog { id: settingsDialog; anchors.fill: parent; onClosed: editor.forceActiveFocus() }
//     BottomToolbar { onSettingsClicked: settingsDialog.open(); onShortcutsClicked: settingsDialog.open("shortcuts") }
// Esc, the X and a click outside the panel close it.
//
// It also applies the choices to the Theme (font and dark mode), so Main.qml needs nothing else.
//
// What it needs from SettingsController:
//   darkTheme, fontFamily, fontSize, indentWidth, useTabs, autoCloseBrackets, showMinimap, hidePointerWhileTyping
//   setDarkTheme(on), setFontFamily(name), setFontSize(n), setIndentWidth(n), setUseTabs(on),
//   setAutoCloseBrackets(on), setShowMinimap(on), setHidePointerWhileTyping(on)
//   qtVersion
// and from UpdateController (the About page): available, latestVersion, status, busy, canInstall, readyToRestart,
//   autoCheck, setAutoCheck(on), checkNow(), updateNow(), openReleasePage()
Item {
    id: root

    signal closed()

    property bool opened: false
    property bool choosingFont: false        // the list of fonts is shown over the settings
    property string page: "appearance"       // appearance, editor, shortcuts or about
    function open(startPage) { choosingFont = false; page = startPage || "appearance"; opened = true; forceActiveFocus() }
    function close() { if (!opened) return; opened = false; choosingFont = false; closed() }

    readonly property string sourceUrl: "https://github.com/ChandanDasGIT/ChaoticNotepad"

    onPageChanged: {
        scroller.contentY = 0
        forceActiveFocus()                   // the shortcuts page may have had the keyboard
    }

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

    // one line of the sidebar
    component SideButton: Rectangle {
        id: side
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked()

        width: parent.width
        height: 34
        radius: 5
        color: selected ? Qt.alpha(Theme.accent, 0.18) : sideArea.containsMouse ? Theme.hoverBg : "transparent"

        Text {
            id: sideIcon
            x: 10
            width: 16
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: side.icon
            font.family: Icon.fontFamily
            font.pixelSize: 12
            color: side.selected ? Theme.accent : Theme.iconDefault
        }
        Text {
            anchors.left: sideIcon.right
            anchors.leftMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: side.label
            color: side.selected ? Theme.text : Theme.iconDefault
            font.pixelSize: Theme.uiFontSize + 1
        }
        MouseArea {
            id: sideArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: side.clicked()
        }
    }

    // a small button on the About page
    component AboutButton: Rectangle {
        id: aboutButton
        property string label: ""
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 28
        radius: 5
        opacity: enabled ? 1 : 0.4
        color: buttonArea.containsMouse ? Theme.hoverBg : Theme.findFieldBg
        border.width: 1
        border.color: Theme.findFieldBorder
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: aboutButton.label
            color: Theme.text
            font.pixelSize: Theme.uiFontSize + 1
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: aboutButton.clicked()
        }
    }

    // a value on the About page
    component AboutValue: Text {
        color: Theme.text
        font.pixelSize: Theme.uiFontSize + 1
    }

    // ---- the panel ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(680, root.width - 32)
        height: Math.min(540, root.height - 32)
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

        // ---- the sidebar ----
        Item {
            id: sidebar
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 204

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                SideButton {
                    icon: Icon.palette
                    label: "Appearance"
                    selected: root.page === "appearance"
                    onClicked: root.page = "appearance"
                }
                SideButton {
                    icon: Icon.pen
                    label: "Editor"
                    selected: root.page === "editor"
                    onClicked: root.page = "editor"
                }
                SideButton {
                    icon: Icon.keyboard
                    label: "Keyboard shortcuts"
                    selected: root.page === "shortcuts"
                    onClicked: root.page = "shortcuts"
                }
                SideButton {
                    icon: Icon.info
                    label: "About"
                    selected: root.page === "about"
                    onClicked: root.page = "about"
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.stickyDivider
            }
        }

        // ---- the page ----
        Flickable {
            id: scroller
            visible: root.page !== "shortcuts"
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: pageScroll
                visible: scroller.contentHeight > scroller.height
                width: 10
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: pageScroll.pressed ? Theme.scrollbarHandlePressed
                         : pageScroll.hovered ? Theme.scrollbarHandleHover : Theme.scrollbarHandle
                }
                background: Item {}
            }

            ColumnLayout {
                id: content
                width: parent.width - 14                 // room for the scrollbar
                spacing: 0

                // ---- Appearance ----
                Text {
                    visible: root.page === "appearance"
                    Layout.topMargin: 4
                    text: "APPEARANCE"
                    color: Theme.accent
                    font.pixelSize: Theme.uiFontSize - 1
                    font.bold: true
                    font.letterSpacing: 1
                }
                SettingsRow {
                    visible: root.page === "appearance"
                    Layout.fillWidth: true
                    title: "Dark theme"
                    description: "Turn off for the light theme."
                    SettingsSwitch {
                        checked: SettingsController.darkTheme
                        onToggled: (on) => SettingsController.setDarkTheme(on)
                    }
                }
                SettingsRow {
                    visible: root.page === "appearance"
                    Layout.fillWidth: true
                    title: "Editor font"
                    description: "Any installed font. Monospace fonts look best."
                    Rectangle {                              // shows the font in use; a click opens the list
                        width: Math.min(190, content.width / 2)
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
                    visible: root.page === "appearance"
                    Layout.fillWidth: true
                    title: "Font size"
                    SettingsStepper {
                        from: 8
                        to: 32
                        value: SettingsController.fontSize
                        onValueModified: (v) => SettingsController.setFontSize(v)
                    }
                }

                // ---- Editor ----
                Text {
                    visible: root.page === "editor"
                    Layout.topMargin: 4
                    text: "EDITOR"
                    color: Theme.accent
                    font.pixelSize: Theme.uiFontSize - 1
                    font.bold: true
                    font.letterSpacing: 1
                }
                SettingsRow {
                    visible: root.page === "editor"
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
                    visible: root.page === "editor"
                    Layout.fillWidth: true
                    title: "Indent with tabs"
                    description: "Use a tab character instead of spaces."
                    SettingsSwitch {
                        checked: SettingsController.useTabs
                        onToggled: (on) => SettingsController.setUseTabs(on)
                    }
                }
                SettingsRow {
                    visible: root.page === "editor"
                    Layout.fillWidth: true
                    title: "Close brackets and quotes"
                    description: "Typing ( [ { or a quote adds the closing one."
                    SettingsSwitch {
                        checked: SettingsController.autoCloseBrackets
                        onToggled: (on) => SettingsController.setAutoCloseBrackets(on)
                    }
                }
                SettingsRow {
                    visible: root.page === "editor"
                    Layout.fillWidth: true
                    title: "Show minimap"
                    description: "The small picture of the file at the right. Alt+M does the same."
                    SettingsSwitch {
                        checked: SettingsController.showMinimap
                        onToggled: (on) => SettingsController.setShowMinimap(on)
                    }
                }
                SettingsRow {
                    visible: root.page === "editor"
                    Layout.fillWidth: true
                    title: "Hide mouse pointer while typing"
                    description: "It comes back when you move the mouse."
                    SettingsSwitch {
                        checked: SettingsController.hidePointerWhileTyping
                        onToggled: (on) => SettingsController.setHidePointerWhileTyping(on)
                    }
                }

                // ---- About ----
                Text {
                    visible: root.page === "about"
                    Layout.topMargin: 4
                    text: "ChaoticNotepad"
                    color: Theme.text
                    font.pixelSize: Theme.uiFontSize + 8
                    font.bold: true
                }
                Text {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 6
                    text: "A modern, minimalist text and code editor for Linux."
                    wrapMode: Text.WordWrap
                    color: Theme.iconDefault
                    font.pixelSize: Theme.uiFontSize + 1
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "Version"
                    AboutValue { text: Application.version }
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "Updates"
                    description: UpdateController.status !== "" ? UpdateController.status
                                 : UpdateController.available ? "Version " + UpdateController.latestVersion + " is available."
                                 : "See if a new version is out."
                    AboutButton {
                        visible: !UpdateController.available
                        enabled: !UpdateController.busy
                        label: "Check now"
                        onClicked: UpdateController.checkNow()
                    }
                    AboutButton {
                        visible: UpdateController.available && UpdateController.canInstall
                        enabled: !UpdateController.busy
                        label: UpdateController.readyToRestart ? "Restart to update" : "Update now"
                        onClicked: UpdateController.updateNow()
                    }
                    AboutButton {
                        visible: UpdateController.available && !UpdateController.canInstall
                        label: "Open release page"
                        onClicked: UpdateController.openReleasePage()
                    }
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "Check for updates"
                    description: "Once a day, asks GitHub for the latest version. A green dot in the bottom bar shows a new one."
                    SettingsSwitch {
                        checked: UpdateController.autoCheck
                        onToggled: (on) => UpdateController.setAutoCheck(on)
                    }
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "Qt version"
                    AboutValue { text: SettingsController.qtVersion }
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "License"
                    AboutValue { text: "GPL-3.0" }
                }
                SettingsRow {
                    visible: root.page === "about"
                    Layout.fillWidth: true
                    title: "Source code"
                    AboutValue {
                        text: "Open on GitHub"
                        color: Theme.accent
                        font.underline: linkArea.containsMouse
                        MouseArea {
                            id: linkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(root.sourceUrl)
                        }
                    }
                }
            }
        }

        // ---- the shortcuts have their own list and buttons ----
        ShortcutsPage {
            visible: root.page === "shortcuts"
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
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
