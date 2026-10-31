import QtQuick
import QtQuick.Layouts

// The bar at the very bottom of the window. Only draws and reports clicks: it does nothing by itself.
Rectangle {
    id: root

    property bool canUndo: false
    property bool canRedo: false

    signal newClicked()
    signal openClicked()
    signal saveClicked()
    signal saveAsClicked()
    signal undoClicked()
    signal redoClicked()
    signal findClicked()
    signal shortcutsClicked()
    signal settingsClicked()
    signal updateClicked()

    implicitHeight: Theme.bottomBarHeight
    color: Theme.bottomBarBg

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.toolbarMargin - Theme.toolbarButtonPadding
        anchors.rightMargin: Theme.toolbarMargin - Theme.toolbarButtonPadding
        spacing: 0

        // ---- left: file actions, then undo / redo ----
        ToolbarButton { icon: Icon.newFile;    label: "New";     onClicked: root.newClicked() }
        ToolbarButton { icon: Icon.openFolder; label: "Open";    onClicked: root.openClicked() }
        ToolbarButton { icon: Icon.save;       label: "Save";    onClicked: root.saveClicked() }
        ToolbarButton { icon: Icon.saveAs;     label: "Save As"; onClicked: root.saveAsClicked() }

        Item { Layout.preferredWidth: Theme.toolbarGroupGap }

        ToolbarButton { icon: Icon.undo; label: "Undo"; enabled: root.canUndo; onClicked: root.undoClicked() }
        ToolbarButton { icon: Icon.redo; label: "Redo"; enabled: root.canRedo; onClicked: root.redoClicked() }

        Item { Layout.fillWidth: true }

        // ---- right: a dot when a new version is out, find, shortcuts and settings ----
        Item {
            visible: UpdateController.available
            Layout.preferredWidth: 30
            Layout.fillHeight: true
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: Theme.changeSaved
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.updateClicked()
            }
        }
        ToolbarButton { icon: Icon.search;   label: "Find";     onClicked: root.findClicked() }
        ToolbarButton { icon: Icon.keyboard; label: "Shortcuts"; onClicked: root.shortcutsClicked() }
        ToolbarButton { icon: Icon.settings; label: "Settings"; onClicked: root.settingsClicked() }
    }
}
