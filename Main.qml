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

    Settings {
        id: appSettings
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/NotepadQtQuick/config.conf"
        category: "Preferences"
        property alias fontSize: settingsDialog.fontSize
        property alias fontFamily: settingsDialog.fontFamily
        property alias isDarkTheme: settingsDialog.isDarkTheme
        property alias restoreSession: settingsDialog.restoreSession
        property bool isClosingWindow: false
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

    property bool isSyncingEditor: false
    property int tabPendingClose: -1
    property string fileModifiedOnDisk: ""

    function adjustZoom(delta) {
        settingsDialog.fontSize = Math.max(8, Math.min(36, settingsDialog.fontSize + delta));
    }

    function performSave(targetPath, shouldCloseAfter) {
        var raw = codeEditor.text;
        var textToSave = (!raw || raw.length === 0) ? "" : (raw.endsWith("\n") ? raw : raw + "\n");

        if (FileIO.writeFile(targetPath, textToSave)) {
            appWindow.isSyncingEditor = true;
            codeEditor.text = textToSave;
            codeEditor.diskContent = textToSave;
            appWindow.isSyncingEditor = false;

            var slash = targetPath.lastIndexOf("/");
            var fileName = slash !== -1 ? targetPath.substring(slash + 1) : targetPath;
            tabs.markSaved(targetPath, fileName, textToSave);

            saveSessionState();

            if (shouldCloseAfter && tabPendingClose !== -1) {
                var target = tabPendingClose;
                tabPendingClose = -1;
                tabs.closeTab(target);
            }
            return true;
        }
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

    function openFilePath(fullPath) {
        var cleanPath = fullPath.toString().replace(/^file:\/\//, "");
        var slash = cleanPath.lastIndexOf("/");
        var fileName = slash !== -1 ? cleanPath.substring(slash + 1) : cleanPath;
        var fileText = FileIO.readFile(cleanPath);

        if (tabs.currentTab && tabs.currentTab.content === "" && !tabs.currentTab.isDirty && tabs.currentTab.filePath === "") {
            appWindow.isSyncingEditor = true;
            codeEditor.text = fileText;
            codeEditor.diskContent = fileText;
            appWindow.isSyncingEditor = false;
            tabs.markSaved(cleanPath, fileName, fileText);
        } else {
            tabs.createTab(fileName, cleanPath, fileText);
            codeEditor.diskContent = fileText;
        }
        saveSessionState();
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
            if (tabs.currentTab && tabs.currentTab.filePath === filePath) {
                appWindow.fileModifiedOnDisk = filePath;
                reloadBanner.visible = true;
            }
        }
    }

    // Keyboard Shortcuts
    Shortcut { sequence: "Ctrl+="; onActivated: appWindow.adjustZoom(1) }
    Shortcut { sequence: "Ctrl++"; onActivated: appWindow.adjustZoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: appWindow.adjustZoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: settingsDialog.fontSize = 13 }
    Shortcut { sequence: "Ctrl+F"; onActivated: findBar.show(false) }
    Shortcut { sequence: "Ctrl+H"; onActivated: findBar.show(true) }
    Shortcut { sequence: "Ctrl+S"; onActivated: appWindow.saveActiveFile() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: appWindow.saveActiveFileAs() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: codeEditor.textEdit.undo() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: codeEditor.textEdit.redo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: codeEditor.textEdit.redo() }

    TabController {
        id: tabs
        onEditorTextRequested: function(content) {
            appWindow.isSyncingEditor = true;
            codeEditor.text = content;
            codeEditor.diskContent = (tabs.currentTab && tabs.currentTab.filePath !== "") ? tabs.currentTab.savedContent : "";
            appWindow.isSyncingEditor = false;
            codeEditor.textEdit.forceActiveFocus();
        }
        onCloseBlockedForUnsaved: function(index, title) {
            appWindow.tabPendingClose = index;
            unsavedPrompt.targetIndex = index;
            unsavedPrompt.docTitle = title;
            unsavedPrompt.open();
        }
    }
    onClosing: function(close) {
        saveSessionState();
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
                reloadBanner.visible = false;
                tabs.selectTab(index, codeEditor.text);
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

            CodeEditor {
                id: codeEditor
                anchors.fill: parent
                appPalette: appPalette
                editorFontSize: settingsDialog.fontSize
                editorFontFamily: settingsDialog.fontFamily
                currentFilePath: tabs.currentTab ? tabs.currentTab.filePath : ""
                onTextModified: {
                    if (!appWindow.isSyncingEditor) {
                        tabs.markCurrentDirty(codeEditor.text);
                        if (findBar.visible && !findBar.activeFocus) {
                            findBar.updateSearch();
                        }
                    }
                }
                onZoomRequested: (delta) => appWindow.adjustZoom(delta)
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
                visible: false
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
                                var diskText = FileIO.readFile(tabs.currentTab.filePath);
                                appWindow.isSyncingEditor = true;
                                codeEditor.text = diskText;
                                codeEditor.diskContent = diskText;
                                appWindow.isSyncingEditor = false;
                                tabs.markSaved(null, null, diskText);
                            }
                            reloadBanner.visible = false;
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
                        onClicked: reloadBanner.visible = false
                    }
                }
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
                targetEditor: codeEditor.textEdit
            }
        }

        BottomToolbar {
            Layout.fillWidth: true
            appPalette: appPalette
            canUndo: codeEditor.textEdit.canUndo
            canRedo: codeEditor.textEdit.canRedo
            onNewFileClicked: tabs.createTab()
            onOpenFolderClicked: customFileDialog.openPicker(false)
            onSaveClicked: appWindow.saveActiveFile()
            onSaveAsClicked: appWindow.saveActiveFileAs()
            onUndoClicked: codeEditor.textEdit.undo()
            onRedoClicked: codeEditor.textEdit.redo()
            onSearchClicked: findBar.show(false)
            onSettingsClicked: settingsDialog.open()
        }
    }

    CustomFileDialog {
        id: customFileDialog
        appPalette: appPalette
        onFileConfirmed: function(fullPath, fileName, isSave) {
            if (isSave) {
                appWindow.performSave(fullPath, true);
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
            tabs.closeTab(target);
            saveSessionState();

            // Only quit if the user was actually trying to close the whole window!
            if (appWindow.isClosingWindow) {
                if (tabs.hasUnsavedChanges()) {
                    // Prompt for the next unsaved tab
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
            var tab = tabs.model.get(target);
            if (tab.filePath !== "") {
                appWindow.performSave(tab.filePath, true);
            } else {
                customFileDialog.openPicker(true);
            }
        }
    }
}
