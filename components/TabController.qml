import QtQuick
import NotepadQtQuick

Item {
    id: tabController
    visible: false
    width: 0
    height: 0

    property int currentIndex: 0
    property alias model: tabListModel

    readonly property var currentTab: (tabListModel.count > 0 && currentIndex >= 0 && currentIndex < tabListModel.count)
                                       ? tabListModel.get(currentIndex)
                                       : null

    signal editorTextRequested(string content)
    signal closeBlockedForUnsaved(int index, string title)

    ListModel {
        id: tabListModel
    }

    function createTab(title, filePath, content) {
        var t = (title !== undefined && title !== null) ? title : "untitled";
        var fp = (filePath !== undefined && filePath !== null) ? filePath : "";
        var c = (content !== undefined && content !== null) ? content : "";

        tabListModel.append({
            title: t,
            filePath: fp,
            savedContent: c,
            content: c,
            isDirty: false
        });

        var newIdx = tabListModel.count - 1;
        currentIndex = newIdx;
        tabController.editorTextRequested(c);
        return newIdx;
    }

    function selectTab(newIndex, currentEditorText) {
        if (newIndex < 0 || newIndex >= tabListModel.count || newIndex === currentIndex) return;

        if (currentTab) {
            currentTab.content = currentEditorText;
        }

        currentIndex = newIndex;
        var nextTab = tabListModel.get(newIndex);
        tabController.editorTextRequested(nextTab.content);
    }

    function requestCloseTab(index) {
        if (index < 0 || index >= tabListModel.count) return;
        var tab = tabListModel.get(index);
        if (tab.isDirty) {
            tabController.closeBlockedForUnsaved(index, tab.title);
        } else {
            closeTab(index);
        }
    }

    function closeTab(index) {
        if (index < 0 || index >= tabListModel.count) return;

        var tab = tabListModel.get(index);
        if (tab && tab.filePath !== "") {
            FileIO.unwatchFile(tab.filePath);
        }

        var wasCurrent = (index === currentIndex);
        tabListModel.remove(index);

        if (tabListModel.count === 0) {
            createTab();
            return;
        }

        if (wasCurrent) {
            var nextIndex = Math.min(index, tabListModel.count - 1);
            currentIndex = nextIndex;
            var targetTab = tabListModel.get(nextIndex);
            tabController.editorTextRequested(targetTab.content);
        } else if (index < currentIndex) {
            currentIndex--;
        }
    }

    function markSaved(filePath, fileName, content) {
        if (!currentTab) return;
        if (filePath !== null && filePath !== undefined) currentTab.filePath = filePath;
        if (fileName !== null && fileName !== undefined) currentTab.title = fileName;
        currentTab.savedContent = content;
        currentTab.content = content;
        currentTab.isDirty = false;
    }

    function markCurrentDirty(editorText) {
        if (!currentTab) return;
        currentTab.content = editorText;
        currentTab.isDirty = (currentTab.savedContent !== editorText);
    }

    function hasUnsavedChanges() {
        for (var i = 0; i < tabListModel.count; ++i) {
            if (tabListModel.get(i).isDirty) return true;
        }
        return false;
    }

    Component.onCompleted: {
        if (tabListModel.count === 0) {
            createTab();
        }
    }
}