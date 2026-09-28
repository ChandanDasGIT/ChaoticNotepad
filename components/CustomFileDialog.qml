import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import NotepadQtQuick

Popup {
    id: filePopup
    width: 620
    height: 440
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    required property QtObject appPalette
    property bool isSaveMode: false
    property url currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property bool showHiddenFiles: false

    signal fileConfirmed(string fullPath, string fileName, bool isSave)

    function openPicker(saveMode) {
        isSaveMode = saveMode;
        fileNameInput.text = saveMode ? "untitled.txt" : "";
        filePopup.open();
        dirView.positionViewAtBeginning();
    }

    background: Rectangle {
        color: appPalette.popupBg
        radius: 10
        border.color: appPalette.border
        border.width: 1
    }

    Shortcut {
        sequence: "Ctrl+H"
        onActivated: hiddenSwitch.checked = !hiddenSwitch.checked
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Header: Navigation & Path Field
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "▲ Up"
                contentItem: Text {
                    text: parent.text
                    color: appPalette.textMain
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 54
                    implicitHeight: 28
                    color: parent.down ? appPalette.highlight : appPalette.tabBg
                    border.color: appPalette.border
                    radius: 4
                }
                onClicked: {
                    if (folderModel.parentFolder.toString() !== "") {
                        filePopup.currentFolder = folderModel.parentFolder;
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: appPalette.editorBg
                border.color: appPalette.border
                radius: 4

                TextInput {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    color: appPalette.textMain
                    text: folderModel.folder.toString().replace("file://", "")
                    selectByMouse: true
                    onAccepted: {
                        var cleaned = text.startsWith("/") ? "file://" + text : text;
                        filePopup.currentFolder = cleaned;
                    }
                }
            }

            // Hidden Files Checkbox
            CheckBox {
                id: hiddenSwitch
                checked: filePopup.showHiddenFiles
                onCheckedChanged: filePopup.showHiddenFiles = checked

                contentItem: Text {
                    text: "Hidden"
                    font.pixelSize: 11
                    color: appPalette.textMain
                    leftPadding: hiddenSwitch.indicator.width + 4
                    verticalAlignment: Text.AlignVCenter
                }

                indicator: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    x: hiddenSwitch.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 3
                    color: appPalette.editorBg
                    border.color: hiddenSwitch.checked ? appPalette.highlight : appPalette.border

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 2
                        color: appPalette.highlight
                        visible: hiddenSwitch.checked
                    }
                }
            }
        }

        // Folder & File List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: appPalette.editorBg
            border.color: appPalette.border
            radius: 6
            clip: true

            ListView {
                id: dirView
                anchors.fill: parent
                anchors.margins: 4
                boundsBehavior: Flickable.StopAtBounds

                model: FolderListModel {
                    id: folderModel
                    folder: filePopup.currentFolder
                    showDirsFirst: true
                    showDotAndDotDot: false
                    showHidden: filePopup.showHiddenFiles
                }

                delegate: Rectangle {
                    id: fileDelegate
                    width: dirView.width
                    height: 26
                    radius: 4
                    color: fileMouse.containsMouse ? appPalette.tabBg : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: fileIsDir ? "\uD83D\uDCC1" : "\uD83D\uDCC4"
                            font.pixelSize: 12
                        }

                        Text {
                            text: fileName
                            font.pixelSize: 12
                            color: fileName.startsWith(".") ? appPalette.textMuted : appPalette.textMain
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: fileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onDoubleClicked: {
                            if (fileIsDir) {
                                filePopup.currentFolder = fileUrl;
                            } else {
                                var diskPath = filePath.toString().replace("file://", "");
                                filePopup.fileConfirmed(diskPath, fileName, filePopup.isSaveMode);
                                filePopup.close();
                            }
                        }
                        onClicked: {
                            if (!fileIsDir) {
                                fileNameInput.text = fileName;
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { }
            }
        }

        // File Selection Row & Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "File:"
                font.pixelSize: 12
                color: appPalette.textMain
            }

            Rectangle {
                Layout.fillWidth: true
                height: 30
                color: appPalette.editorBg
                border.color: appPalette.border
                radius: 4

                TextInput {
                    id: fileNameInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    color: appPalette.textMain
                    selectByMouse: true
                    onAccepted: confirmBtn.clicked()
                }
            }

            Button {
                id: confirmBtn
                text: filePopup.isSaveMode ? "Save" : "Open"
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 80
                    implicitHeight: 30
                    color: parent.down ? Qt.darker(appPalette.highlight, 1.2) : appPalette.highlight
                    radius: 4
                }
                onClicked: {
                    if (fileNameInput.text.trim() === "") return;
                    var baseDir = folderModel.folder.toString().replace("file://", "");
                    var full = baseDir + "/" + fileNameInput.text.trim();
                    filePopup.fileConfirmed(full, fileNameInput.text.trim(), filePopup.isSaveMode);
                    filePopup.close();
                }
            }

            Button {
                text: "Cancel"
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 12
                    color: appPalette.textMain
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 30
                    color: parent.down ? appPalette.highlight : appPalette.tabBg
                    border.color: appPalette.border
                    radius: 4
                }
                onClicked: filePopup.close()
            }
        }
    }
}