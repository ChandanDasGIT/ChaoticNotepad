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

    // "+" is pinned to the right edge and never scrolls away
    Rectangle {
        id: plusButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 34
        color: root.appPalette.tabBg
        z: 3

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 18
            color: plusHover.hovered ? root.appPalette.iconHover : root.appPalette.iconNormal
        }

        HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.newTabRequested() }
    }

    ListView {
        id: tabsListView
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: plusButton.left
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.tabsModel

        readonly property real maxX: Math.max(0, contentWidth - width)

        ScrollBar.horizontal: ScrollBar {
            id: tabScroll
            policy: tabsListView.contentWidth > tabsListView.width ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            height: 4
            z: 5
            contentItem: Rectangle {
                implicitHeight: 4
                radius: 2
                color: root.appPalette.textMuted
                opacity: tabScroll.pressed || tabScroll.hovered ? 0.8 : 0.4
            }
            background: Item {}
        }

        // Keep the current tab in view (new tab, Ctrl+Tab, restore)
        function showCurrent() {
            if (root.currentTabIndex >= 0 && root.currentTabIndex < count)
                positionViewAtIndex(root.currentTabIndex, ListView.Contain);
        }
        Connections {
            target: root
            function onCurrentTabIndexChanged() { Qt.callLater(tabsListView.showCurrent); }
        }
        onCountChanged: Qt.callLater(showCurrent)

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
                    text: tabItem.title
                    color: root.currentTabIndex === tabItem.index ? root.appPalette.textMain : root.appPalette.textMuted
                    font.family: "Monospace"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: tabItem.isDirty
                    text: "•"
                    color: root.currentTabIndex === tabItem.index ? root.appPalette.textMain : root.appPalette.textMuted
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
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
    }

    // Wheel over the tab strip scrolls it sideways. NoButton = clicks still reach the tabs.
    MouseArea {
        anchors.fill: tabsListView
        z: 10
        acceptedButtons: Qt.NoButton

        onWheel: function(wheel) {
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            tabsListView.contentX = Math.max(0, Math.min(tabsListView.maxX, tabsListView.contentX - d));
            wheel.accepted = true;
        }
    }
}
