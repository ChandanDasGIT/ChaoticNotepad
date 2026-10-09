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

    signal closeBlockedForUnsaved(int index, string title)

    // Roles: title, filePath, isDirty, externallyModified,
    //        savedText (what is on disk / last saved), originalText (baseline for the gutter diff).
    // The live text of each tab lives in that tab's own editor.
    ListModel {
        id: tabListModel
    }

    function createTab(title, filePath, content) {
        var t = (title !== undefined && title !== null && title !== "") ? title : "untitled";
        var fp = (filePath !== undefined && filePath !== null) ? filePath : "";
        var c = (content !== undefined && content !== null) ? content : "";

        tabListModel.append({
            title: t,
            filePath: fp,
            isDirty: false,
            externallyModified: false,
            savedText: c,
            originalText: c
        });

        currentIndex = tabListModel.count - 1;
        return currentIndex;
    }

    // The second argument is ignored; old callers still pass the editor text
    function selectTab(newIndex) {
        if (newIndex < 0 || newIndex >= tabListModel.count || newIndex === currentIndex) return;
        currentIndex = newIndex;
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
        tabListModel.remove(index);   // destroys that tab's editor, and its undo history with it

        if (tabListModel.count === 0) {
            createTab();
            return;
        }

        if (wasCurrent) {
            currentIndex = Math.min(index, tabListModel.count - 1);
        } else if (index < currentIndex) {
            currentIndex--;
        }
    }

    function markSaved(filePath, fileName, content, resetOriginal) {
        if (currentIndex < 0 || currentIndex >= tabListModel.count) return;
        if (filePath !== null && filePath !== undefined) tabListModel.setProperty(currentIndex, "filePath", filePath);
        if (fileName !== null && fileName !== undefined) tabListModel.setProperty(currentIndex, "title", fileName);
        tabListModel.setProperty(currentIndex, "savedText", content);
        if (resetOriginal === true) tabListModel.setProperty(currentIndex, "originalText", content);
        tabListModel.setProperty(currentIndex, "isDirty", false);
        tabListModel.setProperty(currentIndex, "externallyModified", false);
    }

    function markDirtyAt(index, editorText) {
        if (index < 0 || index >= tabListModel.count) return;
        var tab = tabListModel.get(index);
        var dirty = (tab.savedText !== editorText);
        if (tab.isDirty !== dirty) {
            tabListModel.setProperty(index, "isDirty", dirty);
        }
    }

    function markCurrentDirty(editorText) {
        markDirtyAt(currentIndex, editorText);
    }

    function setExternallyModified(index, value) {
        if (index < 0 || index >= tabListModel.count) return;
        if (tabListModel.get(index).externallyModified !== value)
            tabListModel.setProperty(index, "externallyModified", value);
    }

    function hasUnsavedChanges() {
        for (var i = 0; i < tabListModel.count; ++i) {
            if (tabListModel.get(i).isDirty) return true;
        }
        return false;
    }

    function getCurrentSavedContent() {
        return currentTab ? currentTab.savedText : "";
    }

    function getCurrentOriginalContent() {
        return currentTab ? currentTab.originalText : "";
    }

    Component.onCompleted: {
        if (tabListModel.count === 0) {
            createTab();
        }
    }
}
