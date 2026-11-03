import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    minimumWidth: 480
    minimumHeight: 300
    visible: true
    title: "ChaoticNotepad"
    color: Theme.editorBg

    // Closing the window (the X, Super+C ...) asks about unsaved tabs first
    onClosing: (close) => { close.accepted = DialogController.closeRequested() }

    Connections {
        target: MarkdownController
        function onStateChanged() {
            if (!MarkdownController.previewOpen) editor.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- tab bar ----
        DocumentTabBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.tabBarHeight
            model: TabsController.tabs
            currentIndex: TabsController.current
            onTabClicked: (i) => TabsController.select(i)
            onTabCloseRequested: (i) => TabsController.closeTab(i)
            onNewTabRequested: TabsController.newTab()
            onTabMoveRequested: (from, to) => TabsController.moveTab(from, to)
        }

        // ---- gutter | text area | minimap | markdown preview ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Hidden when full-preview is open (Ctrl+Shift+V)
            Gutter {
                visible: !MarkdownController.previewOpen
                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth
                contentY: editor.contentY
                cellWidth: editor.cellWidth
                onScrolled: (dy) => editor.scrollBy(dy)
            }
            CodeEditor {
                id: editor
                visible: !MarkdownController.previewOpen
                Layout.fillWidth: true
                Layout.preferredWidth: MarkdownController.splitOpen ? parent.width / 2 : -1
                Layout.fillHeight: true
                focus: true
            }
            Minimap {
                visible: !MarkdownController.previewOpen
                Layout.fillHeight: true
                Layout.preferredWidth: Theme.minimapWidth
                onScrolled: (dy) => editor.scrollBy(dy)
            }

            // Shared Markdown preview for both modes:
            //   previewOpen = full-width toggle (Ctrl+Shift+V)
            //   splitOpen   = side-by-side split (Ctrl+Alt+V)
            MarkdownPreview {
                visible: MarkdownController.previewOpen || MarkdownController.splitOpen
                Layout.fillWidth: true
                Layout.preferredWidth: MarkdownController.splitOpen ? parent.width / 2 : -1
                Layout.fillHeight: true
            }
        }

        // ---- find & replace bar ----
        FindReplaceBar {
            Layout.fillWidth: true
            onClosed: editor.forceActiveFocus()
        }

        // ---- status bar ----
        BottomStatusbar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.statusBarHeight
            message: StatusController.message
            line: StatusController.line
            column: StatusController.column
            selectedChars: StatusController.selectedChars
            cursorCount: StatusController.cursorCount
            indent: StatusController.indent
            encoding: StatusController.encoding
            lineEnding: StatusController.lineEnding
            language: StatusController.language
            lines: StatusController.lines
            words: StatusController.words
            paragraphs: StatusController.paragraphs
        }

        // ---- bottom bar ----
        BottomToolbar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.bottomBarHeight
            canUndo: EditorController.canUndo
            canRedo: EditorController.canRedo
            onNewClicked: TabsController.newTab()
            onOpenClicked: BrowserController.openFile()
            onSaveClicked: EditorController.save()
            onSaveAsClicked: BrowserController.saveFileAs()
            onUndoClicked: EditorController.undo()
            onRedoClicked: EditorController.redo()
            onFindClicked: FindController.openFind()
            onShortcutsClicked: settingsDialog.open("shortcuts")
            onSettingsClicked: settingsDialog.open()
            onUpdateClicked: settingsDialog.open("about")
            onPreviewClicked: MarkdownController.toggleFullPreview()
            onSplitClicked: MarkdownController.toggleSplitPreview()
        }
    }

    // ---- files dropped on the window open in new tabs ----
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls) EditorController.openUrls(drop.urls)
        }
    }

    // ---- settings dialog ----
    SettingsDialog {
        id: settingsDialog
        anchors.fill: parent
        onClosed: editor.forceActiveFocus()
    }

    // ---- open / save as box ----
    FileBrowserDialog {
        anchors.fill: parent
        onClosed: editor.forceActiveFocus()
    }

    // ---- question box (over everything, so it comes last) ----
    PromptDialog {
        anchors.fill: parent
        onClosed: editor.forceActiveFocus()
    }
}
