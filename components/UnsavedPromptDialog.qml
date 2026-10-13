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

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: 360
    z: 9999

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    property bool decided: false

    onSaveRequested: decided = true
    onDiscardRequested: decided = true
    onCancelRequested: decided = true

    onOpened: {
        decided = false;
        saveBtn.forceActiveFocus();
    }

    // Closed any other way (e.g. Esc handled by the Popup) counts as Cancel
    onClosed: {
        if (!decided) cancelRequested();
    }

    background: Rectangle {
        color: (root.appPalette && root.appPalette.popupBg) ? root.appPalette.popupBg : "#21252b"
        border.color: (root.appPalette && root.appPalette.border) ? root.appPalette.border : "#333333"
        border.width: 1
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 16
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.saveRequested();
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelRequested();
                root.close();
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
                root.discardRequested();
                root.close();
                event.accepted = true;
            }
        }

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

            // 2. Cancel
            Button {
                id: cancelBtn
                contentItem: Text {
                    text: "Cancel"
                    font.pixelSize: 12
                    color: cancelBtn.hovered ? (root.appPalette ? root.appPalette.textMain : "#abb2bf") : (root.appPalette ? root.appPalette.textMain : "#abb2bf")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 28
                    radius: 4
                    color: cancelBtn.down ? (root.appPalette ? root.appPalette.highlight : "#528bff")
                    : (cancelBtn.hovered ? (root.appPalette ? root.appPalette.hoverBg : "#2c313a")
                    : (root.appPalette ? root.appPalette.tabBg : "#21252b"))
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
