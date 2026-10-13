import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 420
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 18

    property QtObject appPalette: null
    property int fontSize: 13
    property string fontFamily: "Monospace"
    property bool isDarkTheme: true
    property bool restoreSession: false

    background: Rectangle {
        color: dialog.appPalette ? dialog.appPalette.popupBg : "#21252b"
        border.color: dialog.appPalette ? dialog.appPalette.border : "#181a1f"
        border.width: 1
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 16

        // Title Header
        Text {
            text: "Settings"
            font.bold: true
            font.pixelSize: 14
            color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
            Layout.fillWidth: true
        }

        // 1. Font Family Selector
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Editor Font"
                font.pixelSize: 12
                color: dialog.appPalette ? dialog.appPalette.textMuted : "#5c6370"
            }

            ComboBox {
                id: fontCombo
                Layout.fillWidth: true
                model: {
                    var allFonts = Qt.fontFamilies();
                    var monoList = ["Monospace"];

                    var noisyKeywords = [
                        "Condensed", "ExtraCondensed", "SemiCondensed",
                        "Thin", "ExtraThin", "ExtraLight", "UltraLight",
                        "Black", "ExtraBlack", "Heavy"
                    ];

                    for (var i = 0; i < allFonts.length; ++i) {
                        var name = allFonts[i];
                        var isMono = (name.indexOf("Mono") !== -1 ||
                                      name.indexOf("Code") !== -1 ||
                                      name.indexOf("Courier") !== -1 ||
                                      name.indexOf("Consolas") !== -1);

                        if (!isMono) continue;

                        var hasNoise = false;
                        for (var k = 0; k < noisyKeywords.length; ++k) {
                            if (name.indexOf(noisyKeywords[k]) !== -1) {
                                hasNoise = true;
                                break;
                            }
                        }

                        if (!hasNoise && monoList.indexOf(name) === -1) {
                            monoList.push(name);
                        }
                    }
                    return monoList;
                }

                currentIndex: Math.max(0, model.indexOf(dialog.fontFamily))
                onActivated: function(index) {
                    dialog.fontFamily = model[index];
                }

                background: Rectangle {
                    implicitHeight: 30
                    radius: 4
                    color: dialog.appPalette ? dialog.appPalette.editorBg : "#1e2227"
                    border.color: dialog.appPalette ? dialog.appPalette.border : "#181a1f"
                    border.width: 1
                }

                contentItem: Text {
                    leftPadding: 10
                    rightPadding: fontCombo.indicator.width + 10
                    text: fontCombo.displayText
                    font.pixelSize: 12
                    color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                popup: Popup {
                    id: comboPopup
                    y: fontCombo.height + 4
                    width: fontCombo.width
                    height: Math.min(220, (fontCombo.count * 28) + 12)
                    padding: 4
                    clip: true

                    contentItem: ListView {
                        id: fontListView
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: fontCombo.popup.visible ? fontCombo.delegateModel : null
                        currentIndex: fontCombo.highlightedIndex

                        ScrollBar.vertical: ScrollBar {
                            id: fontScrollBar
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle {
                                radius: 3
                                color: fontScrollBar.hovered ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff")
                                                             : (dialog.appPalette ? dialog.appPalette.textMuted : "#5c6370")
                            }
                        }
                    }

                    background: Rectangle {
                        color: dialog.appPalette ? dialog.appPalette.popupBg : "#282c34"
                        border.color: dialog.appPalette ? dialog.appPalette.border : "#181a1f"
                        border.width: 1
                        radius: 6
                    }
                }

                delegate: ItemDelegate {
                    width: fontCombo.width - 12
                    height: 28
                    highlighted: fontCombo.highlightedIndex === index

                    contentItem: Text {
                        text: modelData
                        color: highlighted ? "#ffffff" : (dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf")
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        radius: 4
                        color: highlighted ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff")
                                           : (hovered ? (dialog.appPalette ? dialog.appPalette.hoverBg : "#2c313a") : "transparent")
                    }
                }
            }
        }

        // 2. Font Size (+ / - Stepper)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Font Size"
                        font.pixelSize: 12
                        color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 4

                        // Minus Button
                        Button {
                            id: decBtn
                            contentItem: Text {
                                text: "−"
                                font.pixelSize: 14
                                font.bold: true
                                color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 4
                                color: decBtn.down ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff")
                                : (decBtn.hovered ? (dialog.appPalette ? dialog.appPalette.hoverBg : "#282c34")
                                : (dialog.appPalette ? dialog.appPalette.editorBg : "#1e2227"))
                                border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"
                                border.width: 1
                            }
                            onClicked: dialog.fontSize = Math.max(8, dialog.fontSize - 1)
                        }

                        // Current Size Display
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 28
                            radius: 4
                            color: dialog.appPalette ? dialog.appPalette.editorBg : "#1e2227"
                            border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: dialog.fontSize.toString()
                                font.pixelSize: 12
                                font.bold: true
                                color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                            }
                        }

                        // Plus Button
                        Button {
                            id: incBtn
                            contentItem: Text {
                                text: "+"
                                font.pixelSize: 14
                                font.bold: true
                                color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 4
                                color: incBtn.down ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff")
                                : (incBtn.hovered ? (dialog.appPalette ? dialog.appPalette.hoverBg : "#282c34")
                                : (dialog.appPalette ? dialog.appPalette.editorBg : "#1e2227"))
                                border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"
                                border.width: 1
                            }
                            onClicked: dialog.fontSize = Math.min(36, dialog.fontSize + 1)
                        }
                    }
                }

        // 3. Dark Theme Switch
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Dark Theme"
                font.pixelSize: 12
                color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                Layout.fillWidth: true
            }

            Switch {
                id: themeSwitch
                checked: dialog.isDarkTheme
                onToggled: dialog.isDarkTheme = checked

                indicator: Rectangle {
                    implicitWidth: 38
                    implicitHeight: 20
                    radius: 10
                    color: themeSwitch.checked ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff") : "#16181d"
                    border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"

                    Rectangle {
                        x: themeSwitch.checked ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: "#abb2bf"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }

        // 4. Restore Previous Session Switch
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Restore Previous Session"
                font.pixelSize: 12
                color: dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf"
                Layout.fillWidth: true
            }

            Switch {
                id: sessionSwitch
                checked: dialog.restoreSession
                onToggled: dialog.restoreSession = checked

                indicator: Rectangle {
                    implicitWidth: 38
                    implicitHeight: 20
                    radius: 10
                    color: sessionSwitch.checked ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff") : "#16181d"
                    border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"

                    Rectangle {
                        x: sessionSwitch.checked ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: "#abb2bf"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 6 }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight

            Item { Layout.fillWidth: true }

            Button {
                id: closeBtn
                contentItem: Text {
                    text: "Close"
                    font.pixelSize: 12
                    color: closeBtn.hovered ? "#ffffff" : (dialog.appPalette ? dialog.appPalette.textMain : "#abb2bf")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 74
                    implicitHeight: 28
                    radius: 4
                    color: closeBtn.down ? (dialog.appPalette ? dialog.appPalette.highlight : "#528bff")
                    : (closeBtn.hovered ? (dialog.appPalette ? dialog.appPalette.hoverBg : "#2c313a")
                    : (dialog.appPalette ? dialog.appPalette.tabBg : "#21252b"))
                    border.color: dialog.appPalette ? dialog.appPalette.border : "#30363d"
                    border.width: 1
                }

                onClicked: dialog.close()
            }
        }
    }
}
