import QtQuick
import QtQuick.Controls

Item {
    id: minimapRoot

    required property Flickable editorFlickable
    required property TextEdit editorTextEdit
    property QtObject appPalette

    implicitWidth: 100
    clip: true

    // Background track
    Rectangle {
        anchors.fill: parent
        color: appPalette ? appPalette.editorBg : "#14161b"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: appPalette ? appPalette.border : "#282c34"
        }
    }

    // Dynamic scale factor to fit the entire document into minimapRoot.height
    readonly property real fittedScale: {
        var unscaledH = microText.implicitHeight;
        if (unscaledH <= 0 || minimapRoot.height <= 0) return 1.0;
        // Never upscale short files; scale down only when text exceeds height
        return Math.min(1.0, minimapRoot.height / unscaledH);
    }

    // Document container pinned to the minimap bounds (no internal scrolling)
    Item {
        id: fullDocContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: minimapRoot.height
        clip: true

        Text {
            id: microText
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 4
            width: (minimapRoot.width - 6) / Math.max(0.01, minimapRoot.fittedScale)

            text: editorTextEdit.text
            textFormat: Text.PlainText
            font.family: editorTextEdit.font.family
            font.pixelSize: 3
            renderType: Text.NativeRendering
            lineHeight: 1.05
            wrapMode: Text.NoWrap
            color: appPalette ? appPalette.textMain : "#abb2bf"
            opacity: 0.90

            transformOrigin: Item.TopLeft
            transform: Scale {
                xScale: minimapRoot.fittedScale
                yScale: minimapRoot.fittedScale
            }
        }
    }

    // Viewport Slider Box
    Rectangle {
        id: viewportSlider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        radius: 3

        color: appPalette ? appPalette.highlight : "#528bff"
        opacity: sliderDrag.pressed ? 0.35 : (sliderDrag.containsMouse ? 0.25 : 0.16)
        border.color: appPalette ? appPalette.highlight : "#61afef"
        border.width: 1

        // Height corresponds directly to visible content ratio
        height: {
            if (editorFlickable.contentHeight <= 0) return minimapRoot.height;
            var ratio = editorFlickable.height / editorFlickable.contentHeight;
            if (ratio >= 1.0) {
                var actualRenderedH = microText.implicitHeight * minimapRoot.fittedScale;
                return Math.max(20, Math.min(minimapRoot.height, actualRenderedH + 4));
            }
            return Math.max(20, Math.min(minimapRoot.height, minimapRoot.height * ratio));
        }

        // Position slides smoothly from 0 to bottom
        y: {
            var maxScroll = editorFlickable.contentHeight - editorFlickable.height;
            if (maxScroll <= 0) return 0;
            var progress = Math.max(0, Math.min(1, editorFlickable.contentY / maxScroll));
            return progress * (minimapRoot.height - height);
        }

        MouseArea {
            id: sliderDrag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            drag.target: parent
            drag.axis: Drag.YAxis
            drag.minimumY: 0
            drag.maximumY: minimapRoot.height - viewportSlider.height

            onPositionChanged: {
                if (drag.active) {
                    var maxRange = minimapRoot.height - viewportSlider.height;
                    var progress = maxRange > 0 ? (viewportSlider.y / maxRange) : 0;
                    editorFlickable.contentY = progress * (editorFlickable.contentHeight - editorFlickable.height);
                }
            }
        }
    }

    // Click anywhere in the column to jump
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            var maxRange = minimapRoot.height - viewportSlider.height;
            if (maxRange <= 0) return;
            var targetY = mouse.y - (viewportSlider.height / 2);
            var clampedY = Math.max(0, Math.min(maxRange, targetY));
            var progress = clampedY / maxRange;
            editorFlickable.contentY = progress * (editorFlickable.contentHeight - editorFlickable.height);
        }
    }
}
