import QtQuick

Item {
    id: root
    width: iconRow.implicitWidth + 14
    height: 24

    property QtObject appPalette: null
    property string iconName: ""
    property string labelText: ""
    signal clicked()

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 4
        color: (mouseArea.containsMouse && root.appPalette) ? root.appPalette.activeTabBg : "transparent"
        border.color: (mouseArea.containsMouse && root.appPalette) ? root.appPalette.border : "transparent"
    }

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: 6

        Canvas {
            id: iconCanvas
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            renderTarget: Canvas.FramebufferObject

            Connections {
                target: root.appPalette
                function onTextMainChanged() { iconCanvas.requestPaint() }
            }

            onPaint: {
                if (!root.appPalette) return;

                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                ctx.strokeStyle = root.appPalette.textMain;
                ctx.fillStyle = root.appPalette.textMain;
                ctx.lineWidth = 1.3;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";

                if (root.iconName === "new") {
                    ctx.strokeRect(2, 1, 10, 12);
                    ctx.beginPath();
                    ctx.moveTo(4, 5); ctx.lineTo(10, 5);
                    ctx.moveTo(4, 8); ctx.lineTo(8, 8);
                    ctx.stroke();
                } else if (root.iconName === "open") {
                    ctx.beginPath();
                    ctx.moveTo(1, 4);
                    ctx.lineTo(5, 4);
                    ctx.lineTo(7, 6);
                    ctx.lineTo(13, 6);
                    ctx.lineTo(13, 12);
                    ctx.lineTo(1, 12);
                    ctx.closePath();
                    ctx.stroke();
                } else if (root.iconName === "save") {
                    ctx.strokeRect(2, 2, 10, 10);
                    ctx.strokeRect(4, 2, 6, 4);
                    ctx.fillRect(4, 8, 6, 3);
                } else if (root.iconName === "save-as") {
                    ctx.strokeRect(1, 2, 9, 10);
                    ctx.strokeRect(3, 2, 5, 3);
                    ctx.fillRect(3, 7, 5, 2.5);
                    ctx.beginPath();
                    ctx.moveTo(11, 8); ctx.lineTo(14, 11);
                    ctx.moveTo(14, 8); ctx.lineTo(11, 11);
                    ctx.stroke();
                } else if (root.iconName === "search") {
                    ctx.beginPath();
                    ctx.arc(5.5, 5.5, 3.5, 0, 2 * Math.PI);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(8, 8);
                    ctx.lineTo(12.5, 12.5);
                    ctx.stroke();
                } else if (root.iconName === "settings") {
                    ctx.beginPath();
                    ctx.arc(7, 7, 2.5, 0, 2 * Math.PI);
                    ctx.stroke();
                    for (var i = 0; i < 6; ++i) {
                        var angle = (i * 60) * Math.PI / 180;
                        var x1 = 7 + Math.cos(angle) * 3.5;
                        var y1 = 7 + Math.sin(angle) * 3.5;
                        var x2 = 7 + Math.cos(angle) * 5.5;
                        var y2 = 7 + Math.sin(angle) * 5.5;
                        ctx.beginPath();
                        ctx.moveTo(x1, y1);
                        ctx.lineTo(x2, y2);
                        ctx.stroke();
                    }
                }
            }
        }

        Text {
            id: lbl
            text: root.labelText
            color: root.appPalette ? root.appPalette.textMain : "#888888"
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            visible: root.labelText !== ""
        }
    }

    onAppPaletteChanged: {
        if (root.appPalette) {
            iconCanvas.requestPaint();
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}