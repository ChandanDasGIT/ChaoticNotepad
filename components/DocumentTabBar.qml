import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 36
    color: appPalette.tabBg

    required property QtObject appPalette
    required property var tabsModel
    required property int currentTabIndex

    signal tabSelected(int index)
    signal closeRequested(int index)
    signal newTabRequested()

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.appPalette.border
        z: 2
    }

    ListView {
        id: tabsListView
        anchors.fill: parent
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.tabsModel

        delegate: Rectangle {
            id: tabItem
            required property int index
            required property string title
            required property bool isDirty

            height: 36
            width: Math.max(120, Math.min(200, tabTitleText.implicitWidth + 46))
            color: root.currentTabIndex === tabItem.index ? root.appPalette.editorBg : root.appPalette.tabBg

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: root.appPalette.highlight
                visible: root.currentTabIndex === tabItem.index
                z: 3
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                width: 1
                color: root.appPalette.border
                visible: root.currentTabIndex !== tabItem.index && root.currentTabIndex !== (tabItem.index + 1)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    id: tabTitleText
                    text: tabItem.title + (tabItem.isDirty ? " •" : "")
                    color: root.currentTabIndex === tabItem.index ? root.appPalette.textMain : root.appPalette.textMuted
                    font.family: "Monospace"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: "×"
                    color: closeHover.hovered ? root.appPalette.iconHover : root.appPalette.textMuted
                    font.pixelSize: 15
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.closeRequested(tabItem.index) }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tabSelected(tabItem.index)
            }
        }

        footer: Rectangle {
            width: 34
            height: 36
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "+"
                font.pixelSize: 18
                color: plusHover.hovered ? root.appPalette.iconHover : root.appPalette.iconNormal
            }

            HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.newTabRequested() }
        }
    }
}