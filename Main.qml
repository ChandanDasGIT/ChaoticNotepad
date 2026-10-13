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

    AppController {
        id: appCtrl
    }

    property bool isSyncingEditor: false
    property var codeEditor: null
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

    onCodeEditorChanged: Qt.callLater(function() {
        if (findBar.visible) findBar.refreshMatches();
    })

    function showError(message) {
        appCtrl.errorText = message;
        errorTimer.restart();
    }

    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: appCtrl.errorText = ""
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

        var textToSave = appCtrl.prepareTextForSave(codeEditor.realText());

        var lineEnding = (tabs.currentTab && tabs.currentTab.lineEnding) ? tabs.currentTab.lineEnding : "\n";
            if (FileIO.writeFile(targetPath, textToSave, lineEnding)) {
            appWindow.isSyncingEditor = true;
            if (codeEditor.realText() !== textToSave) {
                var savedCursor = codeEditor.textEdit.cursorPosition;
                codeEditor.textEdit.insert(codeEditor.textEdit.length, "\n");
                codeEditor.textEdit.cursorPosition = savedCursor;
            }
            Qt.callLater(function() { appWindow.isSyncingEditor = false; });

            var fileName = appCtrl.fileNameFromPath(targetPath);
            tabs.markSaved(targetPath, fileName, textToSave);

            saveSessionState();

            if (shouldCloseAfter && appCtrl.tabPendingClose !== -1) {
                var target = appCtrl.tabPendingClose;
                appCtrl.tabPendingClose = -1;
                tabs.closeTab(target);

                if (appCtrl.isClosingWindow) {
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

        showError("Could not save \"" + targetPath + "\". Check permissions and free space.");
        appCtrl.resetPendingClose();
        return false;
    }

    function saveActiveFile() {
        if (!tabs.currentTab) return;
        if (tabs.currentTab.filePath !== "")
            performSave(tabs.currentTab.filePath, false);
        else
            customFileDialog.openPicker(true);
    }

    function saveActiveFileAs() {
        if (!tabs.currentTab) return;
        customFileDialog.openPicker(true);
    }

    function openFilePath(fullPath) {
        var cleanPath = FileIO.toLocalPath(fullPath.toString());

        // Gather tab paths to let C++ check canonical matches
        var paths = [];
        for (var i = 0; i < tabs.model.count; ++i)
            paths.push(tabs.model.get(i).filePath);

        var existingTab = appCtrl.findTabByPath(paths, cleanPath);
        if (existingTab !== -1) {
            tabs.selectTab(existingTab);
            return true;
        }

        var readResult = FileIO.readFileResult(cleanPath);
        if (!readResult.ok) {
            showError(readResult.error);
            return false;
        }

        var fileName = appCtrl.fileNameFromPath(cleanPath);
        var t = tabs.currentTab;
        var blankIndex = (t && t.filePath === "" && !t.isDirty && t.savedText === "") ? tabs.currentIndex : -1;

        tabs.createTab(fileName, cleanPath, readResult.text, readResult.lineEnding);
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
        var paths = [];
        for (var i = 0; i < tabs.model.count; ++i)
            paths.push(tabs.model.get(i).filePath);

        appSettings.sessionFiles = appCtrl.collectSessionFiles(paths);
    }

    function restoreSessionIfEnabled() {
        if (!settingsDialog.restoreSession) return;

        var files = appSettings.sessionFiles;
        if (typeof files === "string")
            files = (files === "") ? [] : [files];

        if (files && files.length > 0) {
            for (var i = 0; i < files.length; ++i)
                openFilePath(files[i]);
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
    Shortcut { sequence: "Ctrl+="; onActivated: adjustZoom(1) }
    Shortcut { sequence: "Ctrl++"; onActivated: adjustZoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: adjustZoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: settingsDialog.fontSize = 13 }
    Shortcut { sequence: "Ctrl+F"; onActivated: findBar.show(false) }
    Shortcut { sequence: "Ctrl+S"; onActivated: saveActiveFile() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: saveActiveFileAs() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: { if (codeEditor) codeEditor.textEdit.undo(); } }
    Shortcut { sequence: "Ctrl+Y"; onActivated: { if (codeEditor) codeEditor.textEdit.redo(); } }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: { if (codeEditor) codeEditor.textEdit.redo(); } }

    TabController {
        id: tabs

        onCloseBlockedForUnsaved: function(index, title) {
            appCtrl.tabPendingClose = index;
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
            appCtrl.isClosingWindow = true;
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
            openFilePath(initialFileToOpen);
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
            onTabSelected: (index) => tabs.selectTab(index)
            onCloseRequested: (index) => {
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
                        text = savedText;
                        ready = true;
                    }

                    onTextModified: {
                        if (!ready || appWindow.isSyncingEditor) return;
                        tabs.markDirtyAt(index, realText());
                        if (findBar.visible && index === tabs.currentIndex)
                            findBar.refreshMatches();
                    }
                    onZoomRequested: (delta) => adjustZoom(delta)
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
                                    showError(reloadResult.error);
                                     return;
                                }
                                var diskText = reloadResult.text;
                                tabs.setLineEnding(tabs.currentIndex, reloadResult.lineEnding);
                                appWindow.isSyncingEditor = true;
                                codeEditor.text = diskText;
                                Qt.callLater(function() { appWindow.isSyncingEditor = false; });
                                tabs.markSaved(null, null, diskText, true);
                            }
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
                visible: appCtrl.errorText !== ""
                color: appPalette.popupBg
                border.color: appPalette.danger
                border.width: 1

                Text {
                    id: errorLabel
                    anchors.fill: parent
                    anchors.margins: 10
                    text: appCtrl.errorText
                    font.pixelSize: 12
                    color: appPalette.textMain
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }

                TapHandler { onTapped: appCtrl.errorText = "" }
            }

            DropArea {
                id: fileDropArea
                anchors.fill: parent

                onEntered: function(drag) {
                    if (drag.hasUrls) drag.acceptProposedAction();
                }

                onDropped: function(drop) {
                    if (drop.hasUrls) {
                        for (var i = 0; i < drop.urls.length; ++i)
                            openFilePath(drop.urls[i]);
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

                targetEditor: codeEditor ? codeEditor.textEdit : null

                onMatchSelected: function(position) {
                    Qt.callLater(function() {
                        if (codeEditor) codeEditor.ensureVisible(position);
                    });
                }
            }
        }

        BottomToolbar {
            Layout.fillWidth: true
            appPalette: appPalette
            canUndo: codeEditor ? codeEditor.textEdit.canUndo : false
            canRedo: codeEditor ? codeEditor.textEdit.canRedo : false
            onNewFileClicked: tabs.createTab()
            onOpenFolderClicked: customFileDialog.openPicker(false)
            onSaveClicked: saveActiveFile()
            onSaveAsClicked: saveActiveFileAs()
            onUndoClicked: { if (codeEditor) codeEditor.textEdit.undo(); }
            onRedoClicked: { if (codeEditor) codeEditor.textEdit.redo(); }
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
            if (!pickedFile && appCtrl.tabPendingClose !== -1)
                appCtrl.resetPendingClose();
        }

        onFileConfirmed: function(fullPath, fileName, isSave) {
            pickedFile = true;
            if (isSave) {
                var openPaths = [];
                for (var p = 0; p < tabs.model.count; ++p)
                    openPaths.push(tabs.model.get(p).filePath);
                var openIdx = appCtrl.findTabByPath(openPaths, fullPath);
                if (openIdx !== -1 && openIdx !== tabs.currentIndex) {
                    showError("\"" + appCtrl.fileNameFromPath(fullPath)
                    + "\" is already open in another tab. Close that tab first or pick a different name.");
                    Qt.callLater(function() { customFileDialog.openPicker(true); });
                    return;
                }
                var sameAsCurrent = tabs.currentTab && tabs.currentTab.filePath === fullPath;
                if (FileIO.fileExists(fullPath) && !sameAsCurrent) {
                    appCtrl.pendingOverwritePath = fullPath;
                    overwritePrompt.open();
                } else {
                    performSave(fullPath, true);
                }
            } else {
                openFilePath(fullPath);
            }
        }
    }

    UnsavedPromptDialog {
        id: unsavedPrompt
        appPalette: appPalette
        onCancelRequested: appCtrl.resetPendingClose()
        onDiscardRequested: {
            var target = appCtrl.tabPendingClose;
            appCtrl.tabPendingClose = -1;
            if (target < 0 || target >= tabs.model.count) return;
            tabs.closeTab(target);
            saveSessionState();

            if (appCtrl.isClosingWindow) {
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
            var target = appCtrl.tabPendingClose;
            if (target < 0 || target >= tabs.model.count) return;

            if (target !== tabs.currentIndex)
                tabs.selectTab(target);

            var tab = tabs.model.get(target);
            if (tab.filePath !== "") {
                performSave(tab.filePath, true);
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
        onClosed: {
            if (!decided) {
                appCtrl.pendingOverwritePath = "";
                customFileDialog.openPicker(true);
            }
        }

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
                text: "\"" + appCtrl.fileNameFromPath(appCtrl.pendingOverwritePath)
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
                        appCtrl.pendingOverwritePath = "";
                        customFileDialog.openPicker(true);
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
                        var target = appCtrl.pendingOverwritePath;
                        appCtrl.pendingOverwritePath = "";
                        performSave(target, true);
                    }
                }
            }
        }
    }
}
