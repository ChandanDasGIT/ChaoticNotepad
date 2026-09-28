import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    property QtObject appPalette: null
    property int targetIndex: -1
    property string docTitle: ""

    signal saveRequested()
    signal discardRequested()
    signal cancelRequested()

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    closePolicy: Popup.CloseOnEscape
    width: 360

    background: Rectangle {
        color: (root.appPalette && root.appPalette.popupBg) ? root.appPalette.popupBg : "#21252b"
        border.color: (root.appPalette && root.appPalette.border) ? root.appPalette.border : "#333333"
        border.width: 1
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 16

        Label {
            text: root.docTitle !== "" ? ("Save \"" + root.docTitle + "\"?") : "Unsaved Changes"
            font.bold: true
            font.pixelSize: 14
            color: (root.appPalette && root.appPalette.textMain) ? root.appPalette.textMain : "#abb2bf"
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Label {
            text: "Do you want to save changes before closing?"
            font.pixelSize: 12
            color: (root.appPalette && root.appPalette.textMuted) ? root.appPalette.textMuted : "#828997"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            // 1. Don't Save (Danger Red)
            Button {
                id: dontSaveBtn
                contentItem: Text {
                    text: "Don't Save"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 84
                    implicitHeight: 28
                    radius: 4
                    color: dontSaveBtn.down ? Qt.darker((root.appPalette ? root.appPalette.danger : "#e06c75"), 1.25)
                         : (dontSaveBtn.hovered ? Qt.lighter((root.appPalette ? root.appPalette.danger : "#e06c75"), 1.1)
                         : (root.appPalette ? root.appPalette.danger : "#e06c75"))
                }
                onClicked: {
                    root.discardRequested();
                    root.close();
                }
            }

            // 2. Cancel (Dark / Black with border)
            Button {
                id: cancelBtn
                contentItem: Text {
                    text: "Cancel"
                    font.pixelSize: 12
                    color: cancelBtn.hovered ? "#ffffff" : ((root.appPalette && root.appPalette.textMain) ? root.appPalette.textMain : "#abb2bf")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 28
                    radius: 4
                    color: cancelBtn.down ? "#111215"
                         : (cancelBtn.hovered ? "#22252a"
                         : "#16181d")
                    border.color: (root.appPalette && root.appPalette.border) ? root.appPalette.border : "#30363d"
                    border.width: 1
                }
                onClicked: {
                    root.cancelRequested();
                    root.close();
                }
            }

            // 3. Save (Primary Blue Highlight)
            Button {
                id: saveBtn
                contentItem: Text {
                    text: "Save"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 28
                    radius: 4
                    color: saveBtn.down ? Qt.darker((root.appPalette ? root.appPalette.highlight : "#528bff"), 1.25)
                         : (saveBtn.hovered ? Qt.lighter((root.appPalette ? root.appPalette.highlight : "#528bff"), 1.1)
                         : (root.appPalette ? root.appPalette.highlight : "#528bff"))
                }
                onClicked: {
                    root.saveRequested();
                    root.close();
                }
            }
        }
    }
}