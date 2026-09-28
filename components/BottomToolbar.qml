import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 38
    color: appPalette ? appPalette.toolbarBg : "#181a1f"
    border.color: appPalette ? appPalette.border : "#181a1f"
    border.width: 1

    property QtObject appPalette: null

    property bool canUndo: false
    property bool canRedo: false

    signal newFileClicked()
    signal openFolderClicked()
    signal saveClicked()
    signal saveAsClicked()
    signal undoClicked()
    signal redoClicked()
    signal searchClicked()
    signal settingsClicked()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "new"
            labelText: "New"
            onClicked: root.newFileClicked()
        }

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "open"
            labelText: "Open"
            onClicked: root.openFolderClicked()
        }

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "save"
            labelText: "Save"
            onClicked: root.saveClicked()
        }

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "save-as"
            labelText: "Save As"
            onClicked: root.saveAsClicked()
        }

        Rectangle {
            width: 1
            height: 18
            color: root.appPalette ? root.appPalette.border : "#333333"
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }

        Button {
            id: undoBtn
            enabled: root.canUndo
            opacity: enabled ? 1.0 : 0.4
            contentItem: RowLayout {
                spacing: 4
                Text {
                    text: "↶"
                    font.pixelSize: 14
                    font.bold: true
                    color: root.appPalette ? (root.canUndo ? root.appPalette.textMain : root.appPalette.textMuted) : "#888888"
                }
                Text {
                    text: "Undo"
                    font.pixelSize: 11
                    color: root.appPalette ? (root.canUndo ? root.appPalette.textMain : root.appPalette.textMuted) : "#888888"
                }
            }
            background: Rectangle {
                radius: 4
                color: (undoBtn.hovered && root.canUndo && root.appPalette) ? root.appPalette.activeTabBg : "transparent"
            }
            onClicked: root.undoClicked()
        }

        Button {
            id: redoBtn
            enabled: root.canRedo
            opacity: enabled ? 1.0 : 0.4
            contentItem: RowLayout {
                spacing: 4
                Text {
                    text: "↷"
                    font.pixelSize: 14
                    font.bold: true
                    color: root.appPalette ? (root.canRedo ? root.appPalette.textMain : root.appPalette.textMuted) : "#888888"
                }
                Text {
                    text: "Redo"
                    font.pixelSize: 11
                    color: root.appPalette ? (root.canRedo ? root.appPalette.textMain : root.appPalette.textMuted) : "#888888"
                }
            }
            background: Rectangle {
                radius: 4
                color: (redoBtn.hovered && root.canRedo && root.appPalette) ? root.appPalette.activeTabBg : "transparent"
            }
            onClicked: root.redoClicked()
        }

        Item { Layout.fillWidth: true }

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "search"
            labelText: "Find"
            onClicked: root.searchClicked()
        }

        ToolbarIcon {
            appPalette: root.appPalette
            iconName: "settings"
            labelText: "Settings"
            onClicked: root.settingsClicked()
        }
    }
}