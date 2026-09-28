import QtQuick
import NotepadQtQuick

Item {
    id: tabController
    visible: false
    width: 0
    height: 0

    property int currentIndex: 0
    property alias model: tabListModel

    // Internal text buffers separated from the UI ListModel
    property var tabBuffers: []
    property var tabSavedBuffers: []

    readonly property var currentTab: (tabListModel.count > 0 && currentIndex >= 0 && currentIndex < tabListModel.count)
    ? tabListModel.get(currentIndex)
    : null

    signal editorTextRequested(string content)
    signal closeBlockedForUnsaved(int index, string title)

    ListModel {
        id: tabListModel
    }

    function createTab(title, filePath, content) {
        var t = (title !== undefined && title !== null && title !== "") ? title : "untitled";
        var fp = (filePath !== undefined && filePath !== null) ? filePath : "";
        var c = (content !== undefined && content !== null) ? content : "";

        tabBuffers.push(c);
        tabSavedBuffers.push(c);

        tabListModel.append({
            title: t,
            filePath: fp,
            isDirty: false
        });

        var newIdx = tabListModel.count - 1;
        currentIndex = newIdx;
        tabController.editorTextRequested(c);
        return newIdx;
    }

    function selectTab(newIndex, currentEditorText) {
        if (newIndex < 0 || newIndex >= tabListModel.count || newIndex === currentIndex) return;

        // Save current active tab text to memory buffer before switching
        if (currentIndex >= 0 && currentIndex < tabBuffers.length && currentEditorText !== undefined && currentEditorText !== null) {
            tabBuffers[currentIndex] = currentEditorText;
        }

        currentIndex = newIndex;
        var targetContent = (newIndex < tabBuffers.length) ? tabBuffers[newIndex] : "";
        tabController.editorTextRequested(targetContent);
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

        tabBuffers.splice(index, 1);
        tabSavedBuffers.splice(index, 1);

        var wasCurrent = (index === currentIndex);
        tabListModel.remove(index);

        if (tabListModel.count === 0) {
            createTab();
            return;
        }

        if (wasCurrent) {
            var nextIndex = Math.min(index, tabListModel.count - 1);
            currentIndex = nextIndex;
            var contentToLoad = (nextIndex < tabBuffers.length) ? tabBuffers[nextIndex] : "";
            tabController.editorTextRequested(contentToLoad);
        } else if (index < currentIndex) {
            currentIndex--;
        }
    }

    function markSaved(filePath, fileName, content) {
        if (currentIndex < 0 || currentIndex >= tabListModel.count) return;
        if (filePath !== null && filePath !== undefined) tabListModel.setProperty(currentIndex, "filePath", filePath);
        if (fileName !== null && fileName !== undefined) tabListModel.setProperty(currentIndex, "title", fileName);
        tabSavedBuffers[currentIndex] = content;
        tabBuffers[currentIndex] = content;
        tabListModel.setProperty(currentIndex, "isDirty", false);
    }

    function markCurrentDirty(editorText) {
        if (currentIndex < 0 || currentIndex >= tabListModel.count) return;
        tabBuffers[currentIndex] = editorText;
        var saved = (currentIndex < tabSavedBuffers.length) ? tabSavedBuffers[currentIndex] : "";
        var dirty = (saved !== editorText);
        if (tabListModel.get(currentIndex).isDirty !== dirty) {
            tabListModel.setProperty(currentIndex, "isDirty", dirty);
        }
    }

    function hasUnsavedChanges() {
        for (var i = 0; i < tabListModel.count; ++i) {
            if (tabListModel.get(i).isDirty) return true;
        }
        return false;
    }

    function getCurrentSavedContent() {
        if (currentIndex >= 0 && currentIndex < tabSavedBuffers.length) {
            return tabSavedBuffers[currentIndex];
        }
        return "";
    }

    Component.onCompleted: {
        if (tabListModel.count === 0) {
            createTab();
        }
    }
}
