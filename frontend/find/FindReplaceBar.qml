import QtQuick
import QtQuick.Layouts

// The find and replace bar, pinned under the text area.
// Row 1: find field, match counter, previous / next, "select all matches", the four options, close.
// Row 2 (replace mode): replace field, Replace, Replace all.
// Enter = next match (Shift+Enter = previous), Esc = close. In the replace field Enter replaces.
// Place it between the editor row and the status bar in Main.qml and give the focus back to the text on close:
//     FindReplaceBar { Layout.fillWidth: true; onClosed: editor.forceActiveFocus() }
//
// What it needs from FindController:
//   open, replaceOpen               the bar is shown / the replace row is shown
//   findText, replaceText           what the two fields hold (the wrapper may fill them, for example from the selection)
//   matchCase, wholeWord, regex, inSelection   the four options
//   counter, counterIsError         "3 of 12", "No results", "invalid regex"; and whether to draw it in red
//   setFindText(text), setReplaceText(text)
//   next(), prev(), selectAll(), replaceCurrent(), replaceAll()
//   toggleCase(), toggleWord(), toggleRegex(), toggleSelection(), toggleReplace(), close()
//   focusFind(), focusReplace()     signals: put the keyboard in that field (the wrapper sends them when the bar opens)
Rectangle {
    id: root

    signal closed()                              // the bar was closed: give the keyboard back to the text

    visible: FindController.open
    implicitHeight: visible ? column.implicitHeight + 7 + 8 : 0
    color: Theme.findBarBg

    Rectangle {                                  // line on top
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.stickyDivider
    }

    // ---- small parts used below ----

    // a text field
    component Field: Rectangle {
        id: f
        property string value: ""                // what the field should show (kept in step with the wrapper)
        property string placeholder: ""
        property bool error: false
        readonly property string text: input.text
        readonly property bool hasFocus: input.activeFocus

        signal edited(string typed)
        signal accepted(bool backwards)
        signal escaped()
        signal tabbed()

        function focusAndSelect() {
            input.forceActiveFocus()
            input.selectAll()
        }

        implicitHeight: Theme.findFieldHeight
        radius: 4
        color: Theme.findFieldBg
        border.width: 1
        border.color: f.error ? Theme.findError : input.activeFocus ? Theme.accent : Theme.findFieldBorder

        Binding {
            target: input
            property: "text"
            value: f.value
            when: !input.activeFocus          // while you type, the field is the only owner of its text
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            color: Theme.text
            selectionColor: Theme.selectionBg
            selectedTextColor: Theme.text
            font.family: Theme.editorFontFamily
            font.pixelSize: Theme.uiFontSize + 1

            onTextEdited: f.edited(input.text)
            Keys.onReturnPressed: (e) => f.accepted((e.modifiers & Qt.ShiftModifier) !== 0)
            Keys.onEnterPressed: (e) => f.accepted((e.modifiers & Qt.ShiftModifier) !== 0)
            Keys.onEscapePressed: f.escaped()
            Keys.onTabPressed: f.tabbed()
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            visible: input.text.length === 0
            text: f.placeholder
            color: Theme.textDisabled
            font.pixelSize: Theme.uiFontSize + 1
        }
    }

    // a small button with an icon
    component IconButton: Item {
        id: b
        property string icon: ""
        signal clicked()
        implicitWidth: Theme.findFieldHeight
        implicitHeight: Theme.findFieldHeight

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Theme.hoverBg
            visible: area.containsMouse
        }
        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Icon.fontFamily
            font.pixelSize: 13
            color: area.containsMouse ? Theme.text : Theme.iconDefault
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    // a button with a short text; it can be switched on (the options) or be a plain button
    component TextButton: Item {
        id: t
        property string label: ""
        property bool checkable: false
        property bool on: false
        property string tip: ""
        signal clicked()
        implicitWidth: Math.max(Theme.findFieldHeight, caption.implicitWidth + 16)
        implicitHeight: Theme.findFieldHeight

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: t.on ? Qt.alpha(Theme.accent, 0.28) : area.containsMouse ? Theme.hoverBg : "transparent"
            border.width: t.on ? 1 : 0
            border.color: Theme.accent
        }
        Text {
            id: caption
            anchors.centerIn: parent
            text: t.label
            font.pixelSize: Theme.uiFontSize
            color: t.on || area.containsMouse ? Theme.text : Theme.iconDefault
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.clicked()
        }
    }

    // ---- the bar ----
    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 7
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            IconButton {                         // show or hide the replace row
                icon: FindController.replaceOpen ? Icon.chevronDown : Icon.chevronRight
                onClicked: FindController.toggleReplace()
            }

            Field {
                id: findField
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                placeholder: "Find"
                value: FindController.findText
                error: FindController.counterIsError
                onEdited: (typed) => FindController.setFindText(typed)
                onAccepted: (backwards) => backwards ? FindController.prev() : FindController.next()
                onEscaped: FindController.close()
                onTabbed: if (FindController.replaceOpen) replaceField.focusAndSelect()
            }

            Text {                               // "3 of 12"
                Layout.preferredWidth: 84
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: FindController.counter
                font.pixelSize: Theme.uiFontSize
                color: FindController.counterIsError ? Theme.findError : Theme.iconDefault
            }

            IconButton { icon: Icon.arrowUp;   onClicked: FindController.prev() }
            IconButton { icon: Icon.arrowDown; onClicked: FindController.next() }
            TextButton { label: "All"; onClicked: FindController.selectAll() }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.stickyDivider }

            TextButton { label: "Aa";   on: FindController.matchCase;   onClicked: FindController.toggleCase() }
            TextButton { label: "Word"; on: FindController.wholeWord;   onClicked: FindController.toggleWord() }
            TextButton { label: ".*";   on: FindController.regex;       onClicked: FindController.toggleRegex() }
            TextButton { label: "Sel";  on: FindController.inSelection; onClicked: FindController.toggleSelection() }

            IconButton {
                icon: Icon.close
                onClicked: FindController.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: FindController.replaceOpen
            spacing: 4

            Item { Layout.preferredWidth: Theme.findFieldHeight }   // lines the field up with the one above

            Field {
                id: replaceField
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                placeholder: "Replace"
                value: FindController.replaceText
                onEdited: (typed) => FindController.setReplaceText(typed)
                onAccepted: (backwards) => FindController.replaceCurrent()
                onEscaped: FindController.close()
                onTabbed: findField.focusAndSelect()
            }

            TextButton { label: "Replace";     onClicked: FindController.replaceCurrent() }
            TextButton { label: "Replace all"; onClicked: FindController.replaceAll() }
        }

    }

    Connections {
        target: FindController
        function onFocusFind() { findField.focusAndSelect() }
        function onFocusReplace() { replaceField.focusAndSelect() }
        function onOpenChanged() { if (!FindController.open) root.closed() }
    }
}
