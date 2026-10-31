#include "wrapper/dialog/dialogcontroller.h"
#include <algorithm>
#include <QGuiApplication>
#include <QJSEngine>
#include <QQmlEngine>
#include "wrapper/editor/editorcontroller.h"

DialogController* DialogController::instance() {
    static DialogController* inst = new DialogController();
    return inst;
}

DialogController* DialogController::create(QQmlEngine*, QJSEngine*) {
    DialogController* inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);
    return inst;
}

DialogController::DialogController(QObject* parent) : QObject(parent) {
    static int count = 0;
    if (++count > 1) qWarning("DialogController was created twice: QML and the wrappers are using different objects"); 
    connect(EditorController::instance(), &EditorController::documentChanged, this, &DialogController::advance);
    m_poll.setInterval(1000);
    connect(&m_poll, &QTimer::timeout, this, [this] {
        EditorController* ed = EditorController::instance();
        if (m_dialog.active() || ed->inputState().mode != InputMode::Edit) return;
        if (checkExternalChange()) {
            ed->changedOutside(false);
            emit changed();
        }
    });
    m_poll.start();
}

QString DialogController::title() const { return QString::fromStdString(m_dialog.title()); }

QStringList DialogController::lines() const {
    QStringList list;
    for (const std::string& s : m_dialog.lines()) list << QString::fromStdString(s);
    return list;
}

QStringList DialogController::buttons() const {
    QStringList list;
    for (const std::string& s : m_dialog.buttons()) list << QString::fromStdString(s);
    return list;
}

size_t DialogController::indexOfTab(int id) const {
    TabManager& tabs = EditorController::instance()->tabs();
    for (size_t i = 0; i < tabs.count(); ++i)
        if (tabs.at(i).id == id) return i;
    return tabs.count();
}

void DialogController::quitApp() {
    m_quitConfirmed = true;            // quit() asks the window to close: it must not ask about unsaved changes again
    QGuiApplication::quit();
}

// The window was asked to close (the X, Super+C ...). Nothing unsaved: let it close. Otherwise keep the window
// open and ask about the unsaved tabs; the program quits when you have answered for all of them.
bool DialogController::closeRequested() {
    if (m_quitConfirmed) return true;
    if (m_quitting) return false;      // already asking: don't start again from the first tab
    TabManager& tabs = EditorController::instance()->tabs();
    bool unsaved = false;
    for (size_t i = 0; i < tabs.count() && !unsaved; ++i)
        unsaved = tabs.modified(i);
    if (!unsaved) { m_quitConfirmed = true; return true; }
    requestQuit();
    return false;
}

// ------------------------------------------------------------------ keys and clicks

bool DialogController::keyPressed(int key, const QString& text, int modifiers) {
    Input::KeyEvent k;
    k.mods.shift = modifiers & Qt::ShiftModifier;
    k.mods.alt = modifiers & Qt::AltModifier;
    k.mods.ctrl = modifiers & Qt::ControlModifier;

    switch (key) {
    case Qt::Key_Shift: case Qt::Key_Control: case Qt::Key_Alt: case Qt::Key_Meta:
        return false;
    case Qt::Key_Escape: k.key = Input::Key::Escape; break;
    case Qt::Key_Return: case Qt::Key_Enter: k.key = Input::Key::Enter; break;
    case Qt::Key_Left: k.key = Input::Key::Left; break;
    case Qt::Key_Right: k.key = Input::Key::Right; break;
    case Qt::Key_Tab: k.key = Input::Key::Tab; break;
    case Qt::Key_Backtab: k.key = Input::Key::Tab; k.mods.shift = true; break;
    default:
        if (k.mods.ctrl && (key == Qt::Key_S)) {
            k.key = Input::Key::Char;
            k.ch = U's';
        } else if (!text.isEmpty() && text.at(0).unicode() >= 0x20 && text.at(0).unicode() != 0x7f) {
            handle(m_dialog.handleText(text.toUtf8().toStdString()));          // the first letter of a button
            return true;
        } else {
            return false;
        }
    }
    handle(m_dialog.handleKey(k));
    return true;
}

void DialogController::clickButton(int index) {
    handle(m_dialog.clickButton(index));
}

void DialogController::handle(Dialog::Result r) {
    if (r != Dialog::Result::None) {
        onResult(r);
        EditorController::instance()->changedOutside(false);      // tabs may have closed or the status text changed
    }
    emit changed();
}

// ------------------------------------------------------------------ the questions

void DialogController::requestClose(size_t index) {
    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();
    InputState& st = ed->inputState();
    if (index >= tabs.count()) return;

    const std::string name = tabs.title(index);
    if (!tabs.modified(index)) {
        tabs.closeTab(index, true);
        st.status = "closed " + name;
        return;
    }
    m_for = For::CloseTab;
    m_tabId = tabs.at(index).id;
    m_dialog.show("Unsaved changes",
                  {"Do you want to save the changes you made to " + name + "?",
                   "",
                   "Your changes will be lost if you don't save them."});
    emit changed();
}

void DialogController::requestQuit() {
    if (m_quitting) return;
    m_quitting = true;
    m_quitSkipped.clear();
    askNextBeforeQuit();
}

// Quitting goes through the unsaved tabs one at a time. Save and Don't save move on to the next tab,
// Cancel stops quitting. When no tab is left the program quits.
void DialogController::askNextBeforeQuit() {
    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();

    size_t next = tabs.count();
    int left = 0;
    for (size_t i = 0; i < tabs.count(); ++i) {
        if (!tabs.modified(i)) continue;
        if (std::find(m_quitSkipped.begin(), m_quitSkipped.end(), tabs.at(i).id) != m_quitSkipped.end()) continue;
        if (left == 0) next = i;
        ++left;
    }
    if (left == 0) {
        m_quitting = false;
        quitApp();
        return;
    }

    tabs.select(next);
    ed->changedOutside(false);         // the tab the question is about comes to the front

    std::vector<std::string> lines = {"Do you want to save the changes you made to " + tabs.title(next) + "?",
                                      "",
                                      "Your changes will be lost if you don't save them."};
    if (left > 1)
        lines.push_back(std::to_string(left - 1) + (left == 2 ? " more unsaved tab after this one." : " more unsaved tabs after this one."));

    m_for = For::Quit;
    m_tabId = tabs.at(next).id;
    m_dialog.show("Unsaved changes", lines);
    emit changed();
}

void DialogController::showSaveConflict(int tabId, const std::string& name) {
    m_for = For::SaveConflict;
    m_tabId = tabId;
    m_dialog.show("File changed on disk",
                  {name + " was changed by another program since you opened or saved it.",
                   "",
                   "Saving now will overwrite those changes."},
                  {"Overwrite", "Cancel"}, 1, 1);
    emit changed();
}

// Looks at the open file: reloads it quietly if it changed and you have no edits, otherwise asks.
bool DialogController::checkExternalChange() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    EditorTab& tab = ed->tab();

    const Document::DiskState d = tab.doc.checkDisk();
    if (d == Document::DiskState::Unchanged) return false;

    const std::string name = tab.doc.name();
    if (d == Document::DiskState::Deleted) {
        st.status = name + " was deleted on disk - saving will create it again";
        return true;
    }
    if (!tab.doc.modified(tab.view)) {                        // no edits of yours: just show the new version
        std::string msg;
        ed->tabs().reloadTab(ed->tabs().currentIndex(), msg);
        st.status = msg;
        return true;
    }
    long long time = 0, size = 0;
    if (tab.id == m_quietTabId && FileIO::statFile(tab.doc.path(), time, size) && time == m_quietTime && size == m_quietSize)
        return false;
    m_for = For::DiskChanged;
    m_tabId = tab.id;
    m_dialog.show("File changed on disk",
                  {name + " was changed by another program.",
                   "",
                   "Reload: take the disk version (your unsaved changes are lost).",
                   "Keep mine: keep editing; saving overwrites the disk version.",
                   "Compare: open the disk version in a new tab."},
                  {"Reload", "Keep mine", "Compare"}, 1, 1);
    return true;
}

// ------------------------------------------------------------------ the answer

void DialogController::onResult(Dialog::Result r) {
    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();
    InputState& st = ed->inputState();
    const int choice = m_dialog.lastChoice();

    if (m_for == For::DiskChanged) {
        const size_t i = indexOfTab(m_tabId);
        if (i >= tabs.count()) return;
        const std::string name = tabs.at(i).doc.name();
        std::string msg;
        if (choice == 0) { tabs.reloadTab(i, msg); st.status = msg; }
        else if (choice == 1) {
            tabs.at(i).doc.acknowledgeDisk();
            st.status = "keeping your version of " + name + " - saving will overwrite the disk version";
        } else { tabs.openDiskCopy(i, msg); st.status = msg; }
        return;
    }

    if (m_for == For::SaveConflict) {
        const size_t i = indexOfTab(m_tabId);
        if (i >= tabs.count()) return;
        if (choice == 0) st.status = ed->saveTab(tabs.at(i));
        else {
            st.status = "save cancelled";
            m_quietTabId = m_tabId;
            FileIO::statFile(tabs.at(i).doc.path(), m_quietTime, m_quietSize);
        }
        return;
    }

    if (r == Dialog::Result::Cancel) {
        st.status = m_quitting ? "quit cancelled" : "cancelled";
        m_quitting = false;
        return;
    }

    if (m_for == For::CloseTab) {
        const size_t i = indexOfTab(m_tabId);
        if (i >= tabs.count()) return;
        if (r == Dialog::Result::DontSave) {
            const std::string name = tabs.title(i);
            tabs.closeTab(i, true);
            st.status = "closed " + name + " without saving";
        } else {
            m_closeAfterSaveId = m_tabId;
            startSave(i);
        }
    } else {
        const size_t i = indexOfTab(m_tabId);
        if (r == Dialog::Result::DontSave || i >= tabs.count()) {
            m_quitSkipped.push_back(m_tabId);
            askNextBeforeQuit();
        } else {
            m_quitSaveId = m_tabId;
            m_advancing = true;        // advance() looks at the tab when the save has finished, not halfway through
            startSave(i);
            m_advancing = false;
        }
    }
    advance();
}

// Starts saving a tab by sending it Ctrl+S. A tab without a file name gets the Save As box.
void DialogController::startSave(size_t tabIndex) {
    EditorController* ed = EditorController::instance();
    ed->tabs().select(tabIndex);
    ed->sendChar('s', true, false, false);
}

// Runs after every change: finishes "save, then close" and goes on to the next tab after a save while quitting.
void DialogController::advance() {
    if (m_advancing) return;
    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();
    InputState& st = ed->inputState();
    if (st.mode == InputMode::Prompt) return;                  // still waiting for a file name

    m_advancing = true;

    if (m_closeAfterSaveId != 0) {
        const size_t i = indexOfTab(m_closeAfterSaveId);
        m_closeAfterSaveId = 0;
        if (i < tabs.count() && !tabs.modified(i)) {           // saved: close it. Cancelled or failed: keep it open
            const std::string name = tabs.title(i);
            tabs.closeTab(i, true);
            st.status = "saved and closed " + name;
            ed->changedOutside(false);
        }
    }

    if (m_quitSaveId != 0 && !m_dialog.active()) {             // an open box here is the save conflict: wait for it
        const size_t i = indexOfTab(m_quitSaveId);
        m_quitSaveId = 0;
        if (i < tabs.count() && tabs.modified(i)) {            // cancelled or failed: stay on this tab
            m_quitting = false;
            st.status = "quit cancelled";
            ed->changedOutside(false);
        } else {
            askNextBeforeQuit();
        }
    }

    m_advancing = false;
}
