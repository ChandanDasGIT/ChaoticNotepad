import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The list of installed fonts, drawn over the settings dialog. Type to search, click a font to pick it.
// SettingsDialog shows it when the font button is clicked:
//     FontListPanel { anchors.fill: parent; visible: root.choosingFont; current: SettingsController.fontFamily
//                     onPicked: (name) => ...; onCancelled: ... }
Rectangle {
    id: root

    property string current: ""              // the font in use now (shown with a tick)
    signal picked(string name)
    signal cancelled()

    readonly property var families: Qt.fontFamilies()
    property string filter: ""
    readonly property var shown: {
        const f = filter.trim().toLowerCase()
        return f === "" ? families : families.filter(n => n.toLowerCase().indexOf(f) >= 0)
    }

    color: Theme.dialogBg
    focus: visible

    // when the list opens: empty search, the keyboard in the search field, the current font in view
    onVisibleChanged: {
        if (!visible) return
        filter = ""
        search.text = ""
        search.forceActiveFocus()
        Qt.callLater(() => list.positionViewAtIndex(Math.max(0, root.shown.indexOf(root.current)), ListView.Center))
    }

    MouseArea { anchors.fill: parent }       // nothing behind the list gets the mouse

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // title with a way back
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.hoverBg
                    visible: backArea.containsMouse
                }
                Text {
                    anchors.centerIn: parent
                    text: Icon.chevronLeft
                    font.family: Icon.fontFamily
                    font.pixelSize: 13
                    color: backArea.containsMouse ? Theme.text : Theme.iconDefault
                }
                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelled()
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Editor font"
                color: Theme.text
                font.pixelSize: Theme.uiFontSize + 4
                font.bold: true
            }
            Text {
                text: root.shown.length + " fonts"
                color: Theme.iconDefault
                font.pixelSize: Theme.uiFontSize
            }
        }

        // search field
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 4
            color: Theme.findFieldBg
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.findFieldBorder

            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                color: Theme.text
                selectionColor: Theme.selectionBg
                selectedTextColor: Theme.text
                font.pixelSize: Theme.uiFontSize + 1

                onTextChanged: root.filter = text
                Keys.onEscapePressed: root.cancelled()
                Keys.onReturnPressed: if (root.shown.length > 0) root.picked(root.shown[0])
                Keys.onEnterPressed: if (root.shown.length > 0) root.picked(root.shown[0])
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                visible: search.text.length === 0
                text: "Search fonts"
                color: Theme.textDisabled
                font.pixelSize: Theme.uiFontSize + 1
            }
        }

        // the fonts, each in its own typeface
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
                model: root.shown
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: fontScroll
                    policy: ScrollBar.AsNeeded
                    width: 10
                    contentItem: Rectangle {                // the handle
                        implicitWidth: 6
                        radius: 3
                        color: fontScroll.pressed ? Theme.scrollbarHandlePressed
                             : fontScroll.hovered ? Theme.scrollbarHandleHover : Theme.scrollbarHandle
                    }
                    background: Item {}                     // no track behind it
                }

                delegate: Item {
                    id: row
                    required property string modelData
                    width: list.width
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        color: rowArea.containsMouse ? Theme.hoverBg
                             : row.modelData === root.current ? Qt.alpha(Theme.accent, 0.25) : "transparent"
                    }
                    Text {
                        x: 12
                        width: parent.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData
                        font.family: row.modelData
                        font.pixelSize: 15
                        color: Theme.text
                    }
                    Text {
                        visible: row.modelData === root.current
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icon.check
                        font.family: Icon.fontFamily
                        font.pixelSize: 12
                        color: Theme.accent
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(row.modelData)
                    }
                }
            }
        }
    }
}
