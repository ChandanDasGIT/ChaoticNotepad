import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import NotepadQtQuick
import "components"

ApplicationWindow {
    id: appWindow
    width: 1000
    height: 700
    visible: true
    title: (tabs.currentTab ? tabs.currentTab.title : "unsaved")
    + (tabs.currentTab && tabs.currentTab.isDirty ? " *" : "")
    + " - Editor"
    color: appPalette.editorBg

    property bool isSyncingEditor: false
    // The editor of the current tab. Every tab owns its own CodeEditor,
    // so undo history, caret and scroll are per tab.
    property var codeEditor: null
    // Lets delegates reach the palette without the name resolving to their own property
    property alias themePalette: appPalette

    function syncCurrentEditor() {
        var ed = editorRepeater.itemAt(tabs.currentIndex);
        if (ed === appWindow.codeEditor) return;
        appWindow.codeEditor = ed;
        if (ed) {
            Qt.callLater(function() {
                if (appWindow.codeEditor === ed) ed.textEdit.forceActiveFocus();
            });
        }
    }

    // The find bar's matches belonged to the previous tab's text
    onCodeEditorChanged: Qt.callLater(function() {
        if (findBar.visible) findBar.refreshMatches();
    })

    property bool isClosingWindow: false
    property int tabPendingClose: -1
    //property string fileModifiedOnDisk: ""

    property string errorText: ""

    function showError(message) {
        appWindow.errorText = message;
        errorTimer.restart();
    }

    // Forget any half-finished "save then close" request
    function resetPendingClose() {
        appWindow.tabPendingClose = -1;
        appWindow.isClosingWindow = false;
    }

    property string pendingOverwritePath: ""

    function confirmOverwrite() {
        var p = appWindow.pendingOverwritePath;
        appWindow.pendingOverwritePath = "";
        appWindow.performSave(p, true);
    }

    // Back to the picker so the user can choose another name
    function cancelOverwrite() {
        appWindow.pendingOverwritePath = "";
        customFileDialog.openPicker(true);
    }

    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: appWindow.errorText = ""
    }

    Settings {
        id: appSettings
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/NotepadQtQuick/config.conf"
        category: "Preferences"
        property alias fontSize: settingsDialog.fontSize
        property alias fontFamily: settingsDialog.fontFamily
        property alias isDarkTheme: settingsDialog.isDarkTheme
        property alias restoreSession: settingsDialog.restoreSession
        property var sessionFiles: []
    }

    AppPalette {
        id: appPalette
        isDark: settingsDialog.isDarkTheme
    }

    SettingsDialog {
        id: settingsDialog
        appPalette: appPalette
    }

    function adjustZoom(delta) {
        settingsDialog.fontSize = Math.max(8, Math.min(36, settingsDialog.fontSize + delta));
    }

    function performSave(targetPath, shouldCloseAfter) {
        if (!codeEditor) return false;

        var raw = codeEditor.realText();
        var textToSave = (!raw || raw.length === 0) ? "" : (raw.endsWith("\n") ? raw : raw + "\n");

        if (FileIO.writeFile(targetPath, textToSave)) {
            appWindow.isSyncingEditor = true;
            if (codeEditor.realText() !== textToSave) {
                // Only the trailing newline differs: append it instead of replacing
                // the whole text, so the undo history survives
                var savedCursor = codeEditor.textEdit.cursorPosition;
                codeEditor.textEdit.insert(codeEditor.textEdit.length, "\n");
                codeEditor.textEdit.cursorPosition = savedCursor;
            }
            //codeEditor.diskContent = textToSave;
            Qt.callLater(function() { appWindow.isSyncingEditor = false; });

            var slash = targetPath.lastIndexOf("/");
            var fileName = slash !== -1 ? targetPath.substring(slash + 1) : targetPath;
            tabs.markSaved(targetPath, fileName, textToSave);

            saveSessionState();

            if (shouldCloseAfter && tabPendingClose !== -1) {
                var target = tabPendingClose;
                tabPendingClose = -1;
                tabs.closeTab(target);

                if (appWindow.isClosingWindow) {
                    if (tabs.hasUnsavedChanges()) {
                        for (var i = 0; i < tabs.model.count; ++i) {
                            if (tabs.model.get(i).isDirty) {
                                tabs.requestCloseTab(i);
                                break;
                            }
                        }
                    } else {
                        Qt.quit();
                    }
                }
            }
            return true;
        }
        appWindow.showError("Could not save \"" + targetPath + "\". Check permissions and free space.");
        appWindow.resetPendingClose();
        return false;
    }

    function saveActiveFile() {
        if (!tabs.currentTab) return;
        if (tabs.currentTab.filePath !== "") {
            performSave(tabs.currentTab.filePath, false);
        } else {
            customFileDialog.openPicker(true);
        }
    }

    function saveActiveFileAs() {
        if (!tabs.currentTab) return;
        customFileDialog.openPicker(true);
    }

    // Index of the tab already showing this file, or -1
    function findTabByPath(path) {
        var wanted = FileIO.canonicalPath(path);
        for (var i = 0; i < tabs.model.count; ++i) {
            var fp = tabs.model.get(i).filePath;
            if (fp !== "" && FileIO.canonicalPath(fp) === wanted)
                return i;
        }
        return -1;
    }

    function openFilePath(fullPath) {
        var cleanPath = FileIO.toLocalPath(fullPath.toString());

        var existingTab = appWindow.findTabByPath(cleanPath);
        if (existingTab !== -1) {
            tabs.selectTab(existingTab);
            return true;
        }

        var slash = cleanPath.lastIndexOf("/");
        var fileName = slash !== -1 ? cleanPath.substring(slash + 1) : cleanPath;
        var readResult = FileIO.readFileResult(cleanPath);
        if (!readResult.ok) {
            appWindow.showError(readResult.error);
            return false;
        }
        var fileText = readResult.text;

        // A pristine, empty "untitled" tab is replaced by the opened file
        var t = tabs.currentTab;
        var blankIndex = (t && t.filePath === "" && !t.isDirty && t.savedText === "") ? tabs.currentIndex : -1;

        tabs.createTab(fileName, cleanPath, fileText);
        if (blankIndex !== -1)
            tabs.closeTab(blankIndex);

        saveSessionState();
        return true;
    }

    function saveSessionState() {
        if (!settingsDialog.restoreSession) {
            appSettings.sessionFiles = [];
            return;
        }
        var files = [];
        for (var i = 0; i < tabs.model.count; ++i) {
            var fp = tabs.model.get(i).filePath;
            if (fp && fp.length > 0) {
                files.push(fp);
            }
        }
        appSettings.sessionFiles = files;
    }

    function restoreSessionIfEnabled() {
        if (!settingsDialog.restoreSession) return;
        var files = appSettings.sessionFiles;
        if (files && files.length > 0) {
            for (var i = 0; i < files.length; ++i) {
                appWindow.openFilePath(files[i]);
            }
        }
    }

    Connections {
        target: FileIO
        function onExternalFileModified(filePath) {
            for (var i = 0; i < tabs.model.count; ++i) {
                if (tabs.model.get(i).filePath === filePath)
                    tabs.setExternallyModified(i, true);
            }
        }
    }

    Connections {
        target: tabs
        function onCurrentIndexChanged() { appWindow.syncCurrentEditor(); }
    }

    // Keyboard Shortcuts
    Shortcut { sequence: "Ctrl+="; onActivated: appWindow.adjustZoom(1) }
    Shortcut { sequence: "Ctrl++"; onActivated: appWindow.adjustZoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: appWindow.adjustZoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: settingsDialog.fontSize = 13 }
    Shortcut { sequence: "Ctrl+F"; onActivated: findBar.show(false) }
    //Shortcut { sequence: "Ctrl+H"; onActivated: findBar.show(true) }
    Shortcut { sequence: "Ctrl+S"; onActivated: appWindow.saveActiveFile() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: appWindow.saveActiveFileAs() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: { if (appWindow.codeEditor) appWindow.codeEditor.textEdit.undo(); } }
    Shortcut { sequence: "Ctrl+Y"; onActivated: { if (appWindow.codeEditor) appWindow.codeEditor.textEdit.redo(); } }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: { if (appWindow.codeEditor) appWindow.codeEditor.textEdit.redo(); } }

    TabController {
        id: tabs

        onCloseBlockedForUnsaved: function(index, title) {
            appWindow.tabPendingClose = index;
            unsavedPrompt.targetIndex = index;
            unsavedPrompt.docTitle = title;
            unsavedPrompt.open();
        }
    }

    onClosing: function(close) {
        saveSessionState();

        if (unsavedPrompt.visible) {
            close.accepted = false;
            return;
        }

        if (tabs.hasUnsavedChanges()) {
            close.accepted = false;
            appWindow.isClosingWindow = true;
            for (var i = 0; i < tabs.model.count; ++i) {
                if (tabs.model.get(i).isDirty) {
                    tabs.requestCloseTab(i);
                    break;
                }
            }
        } else {
            close.accepted = true;
        }
    }

    Component.onCompleted: {
        restoreSessionIfEnabled();

        if (typeof initialFileToOpen !== "undefined" && initialFileToOpen !== "") {
            appWindow.openFilePath(initialFileToOpen);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        DocumentTabBar {
            Layout.fillWidth: true
            appPalette: appPalette
            tabsModel: tabs.model
            currentTabIndex: tabs.currentIndex
            onTabSelected: function(index) {
                tabs.selectTab(index);
            }
            onCloseRequested: function(index) {
                tabs.requestCloseTab(index);
                saveSessionState();
            }
            onNewTabRequested: tabs.createTab()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Repeater {
                id: editorRepeater
                model: tabs.model
                onItemAdded: appWindow.syncCurrentEditor()
                onItemRemoved: {
                    appWindow.syncCurrentEditor();
                    Qt.callLater(appWindow.syncCurrentEditor);
                }

                delegate: CodeEditor {
                    required property int index
                    required property string filePath
                    required property string savedText
                    required property string originalText

                    property bool ready: false

                    anchors.fill: parent
                    visible: index === tabs.currentIndex
                    appPalette: appWindow.themePalette
                    editorFontSize: settingsDialog.fontSize
                    editorFontFamily: settingsDialog.fontFamily
                    currentFilePath: filePath
                    diskContent: filePath !== "" ? savedText : ""
                    originalContent: originalText

                    Component.onCompleted: {
                        text = savedText;   // the initial load isn't an edit
                        ready = true;
                    }

                    onTextModified: {
                        if (!ready || appWindow.isSyncingEditor) return;
                        tabs.markDirtyAt(index, realText());
                        if (findBar.visible && index === tabs.currentIndex)
                            findBar.refreshMatches();
                    }
                    onZoomRequested: (delta) => appWindow.adjustZoom(delta)
                }
            }

            Rectangle {
                id: reloadBanner
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins: 10
                width: Math.min(parent.width - 40, 520)
                height: 38
                radius: 6
                z: 20
                visible: !!(tabs.currentTab && tabs.currentTab.externallyModified)
                color: appPalette.isDark ? "#2d333b" : "#fff8c5"
                border.color: appPalette.isDark ? "#444c56" : "#d4a72c"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "File modified on disk."
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: appPalette.textMain
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "Reload"
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitWidth: 64
                            implicitHeight: 24
                            radius: 4
                            color: appPalette.highlight
                        }
                        onClicked: {
                            if (tabs.currentTab && tabs.currentTab.filePath !== "") {
                                var reloadResult = FileIO.readFileResult(tabs.currentTab.filePath);
                                if (!reloadResult.ok) {
                                    appWindow.showError(reloadResult.error);
                                    return;
                                }
                                var diskText = reloadResult.text;
                                appWindow.isSyncingEditor = true;
                                codeEditor.text = diskText;
                                //codeEditor.diskContent = diskText;
                                Qt.callLater(function() { appWindow.isSyncingEditor = false; });
                                tabs.markSaved(null, null, diskText, true);
                            }
                            //reloadBanner.visible = false;
                        }
                    }

                    Button {
                        text: "Ignore"
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 11
                            color: appPalette.textMain
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitWidth: 54
                            implicitHeight: 24
                            radius: 4
                            color: "transparent"
                            border.color: appPalette.border
                            border.width: 1
                        }
                        onClicked: tabs.setExternallyModified(tabs.currentIndex, false)
                    }
                }
            }

            Rectangle {
                id: errorBanner
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 14
                width: Math.min(parent.width - 40, 560)
                height: errorLabel.implicitHeight + 20
                radius: 6
                z: 21
                visible: appWindow.errorText !== ""
                color: appPalette.popupBg
                border.color: appPalette.danger
                border.width: 1

                Text {
                    id: errorLabel
                    anchors.fill: parent
                    anchors.margins: 10
                    text: appWindow.errorText
                    font.pixelSize: 12
                    color: appPalette.textMain
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }

                TapHandler { onTapped: appWindow.errorText = "" }
            }

            DropArea {
                id: fileDropArea
                anchors.fill: parent

                onEntered: function(drag) {
                    if (drag.hasUrls) {
                        drag.acceptProposedAction();
                    }
                }

                onDropped: function(drop) {
                    if (drop.hasUrls) {
                        for (var i = 0; i < drop.urls.length; ++i) {
                            appWindow.openFilePath(drop.urls[i]);
                        }
                        drop.acceptProposedAction();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: appPalette.highlight
                    border.width: 2
                    visible: fileDropArea.containsDrag
                    z: 5
                }
            }

            FindReplaceBar {
                id: findBar
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                visible: false
                z: 10
                appPalette: appPalette

                targetEditor: appWindow.codeEditor ? appWindow.codeEditor.textEdit : null

                onMatchSelected: function(position) {
                    // Deferred so the editor has finished laying out any text change
                    Qt.callLater(function() {
                        if (appWindow.codeEditor) appWindow.codeEditor.ensureVisible(position);
                    });
                }
            }
        }

        BottomToolbar {
            Layout.fillWidth: true
            appPalette: appPalette
            canUndo: appWindow.codeEditor ? appWindow.codeEditor.textEdit.canUndo : false
            canRedo: appWindow.codeEditor ? appWindow.codeEditor.textEdit.canRedo : false
            onNewFileClicked: tabs.createTab()
            onOpenFolderClicked: customFileDialog.openPicker(false)
            onSaveClicked: appWindow.saveActiveFile()
            onSaveAsClicked: appWindow.saveActiveFileAs()
            onUndoClicked: { if (appWindow.codeEditor) appWindow.codeEditor.textEdit.undo(); }
            onRedoClicked: { if (appWindow.codeEditor) appWindow.codeEditor.textEdit.redo(); }
            onSearchClicked: findBar.show(false)
            onSettingsClicked: settingsDialog.open()
        }
    }

    CustomFileDialog {
        id: customFileDialog
        appPalette: appPalette

        property bool pickedFile: false
        onOpened: pickedFile = false
        onClosed: {
            if (!pickedFile && appWindow.tabPendingClose !== -1)
                appWindow.resetPendingClose();
        }

        onFileConfirmed: function(fullPath, fileName, isSave) {
            pickedFile = true;
            if (isSave) {
                var sameAsCurrent = tabs.currentTab && tabs.currentTab.filePath === fullPath;
                if (FileIO.fileExists(fullPath) && !sameAsCurrent) {
                    appWindow.pendingOverwritePath = fullPath;
                    overwritePrompt.open();
                } else {
                    appWindow.performSave(fullPath, true);
                }
            } else {
                appWindow.openFilePath(fullPath);
            }
        }
    }

    UnsavedPromptDialog {
        id: unsavedPrompt
        appPalette: appPalette
        onCancelRequested: {
            tabPendingClose = -1;
            appWindow.isClosingWindow = false;
        }
        onDiscardRequested: {
            var target = tabPendingClose;
            tabPendingClose = -1;
            if (target < 0 || target >= tabs.model.count) return;
            tabs.closeTab(target);
            saveSessionState();

            if (appWindow.isClosingWindow) {
                if (tabs.hasUnsavedChanges()) {
                    for (var i = 0; i < tabs.model.count; ++i) {
                        if (tabs.model.get(i).isDirty) {
                            tabs.requestCloseTab(i);
                            break;
                        }
                    }
                } else {
                    Qt.quit();
                }
            }
        }
        onSaveRequested: {
            var target = tabPendingClose;
            if (target < 0 || target >= tabs.model.count) return;

            // performSave()/markSaved() always work on the active tab, so
            // bring the tab being closed to the front first
            if (target !== tabs.currentIndex) {
                //reloadBanner.visible = false;
                tabs.selectTab(target);
            }

            var tab = tabs.model.get(target);
            if (tab.filePath !== "") {
                appWindow.performSave(tab.filePath, true);
            } else {
                customFileDialog.openPicker(true);
            }
        }
    }
    Popup {
        id: overwritePrompt
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 380
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        property bool decided: false
        onOpened: decided = false
        onClosed: { if (!decided) appWindow.cancelOverwrite(); }

        background: Rectangle {
            color: appPalette.popupBg
            border.color: appPalette.border
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 14

            Label {
                text: "Replace existing file?"
                font.bold: true
                font.pixelSize: 14
                color: appPalette.textMain
                Layout.fillWidth: true
            }

            Label {
                text: "\"" + appWindow.pendingOverwritePath.substring(appWindow.pendingOverwritePath.lastIndexOf("/") + 1)
                + "\" already exists. Saving will overwrite its contents."
                font.pixelSize: 12
                color: appPalette.textMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    id: owCancelBtn
                    contentItem: Text {
                        text: "Cancel"
                        font.pixelSize: 12
                        color: appPalette.textMain
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 70
                        implicitHeight: 28
                        radius: 4
                        color: owCancelBtn.down ? appPalette.highlight : appPalette.tabBg
                        border.color: appPalette.border
                        border.width: 1
                    }
                    onClicked: {
                        overwritePrompt.decided = true;
                        overwritePrompt.close();
                        appWindow.cancelOverwrite();
                    }
                }

                Button {
                    id: owReplaceBtn
                    contentItem: Text {
                        text: "Replace"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 80
                        implicitHeight: 28
                        radius: 4
                        color: owReplaceBtn.down ? Qt.darker(appPalette.danger, 1.25) : appPalette.danger
                    }
                    onClicked: {
                        overwritePrompt.decided = true;
                        overwritePrompt.close();
                        appWindow.confirmOverwrite();
                    }
                }
            }
        }
    }
}
