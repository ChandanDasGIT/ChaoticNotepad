import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    onVisibleChanged: {
        if (visible && MarkdownController.previewOpen) previewText.forceActiveFocus()
    }
    color: Theme.editorBg
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        TextEdit {
            id: previewText
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape && MarkdownController.previewOpen) {
                    MarkdownController.toggleFullPreview()
                    event.accepted = true
                } else if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) {
                    event.accepted = EditorController.keyPressed(event.key, event.text, event.modifiers)
                }
            }
            width: parent.width
            padding: 20
            text: MarkdownController.html
            baseUrl: MarkdownController.baseUrl
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            readOnly: true
            selectByMouse: true
            color: SettingsController.darkTheme ? "#abb2bf" : "#383a42"
            onLinkActivated: (link) => {
                const url = Qt.resolvedUrl(link)
                if (/^(https?:|mailto:)/i.test(url.toString()))
                    Qt.openUrlExternally(url)
            }
        }
    }
}
