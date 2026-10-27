#include "wrapper/dialog/dialogcontroller.h"
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

// The window was asked to close (the X, Super+C ...). Nothing unsaved: let it close. Otherwise show the
// "unsaved changes" box and keep the window open; the box quits the program when you have answered.
bool DialogController::closeRequested() {
    if (m_quitConfirmed) return true;
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
    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();

    std::vector<std::string> names;
    for (size_t i = 0; i < tabs.count(); ++i)
        if (tabs.modified(i)) names.push_back(tabs.title(i));
    if (names.empty()) { quitApp(); return; }

    std::vector<std::string> lines;
    lines.push_back(names.size() == 1 ? "1 file has unsaved changes:"
                                      : std::to_string(names.size()) + " files have unsaved changes:");
    for (size_t k = 0; k < names.size() && k < 5; ++k) lines.push_back("  \xE2\x80\xA2 " + names[k]);
    if (names.size() > 5) lines.push_back("  ...and " + std::to_string(names.size() - 5) + " more");
    lines.push_back("");
    lines.push_back("Your changes will be lost if you don't save them.");

    m_for = For::Quit;
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
        else st.status = "save cancelled";
        return;
    }

    if (r == Dialog::Result::Cancel) { st.status = "cancelled"; return; }

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
        if (r == Dialog::Result::DontSave) quitApp();
        else { m_quitAfterSave = true; m_quitTriedId = 0; }
    }
    advance();
}

// Starts saving a tab by sending it Ctrl+S. A tab without a file name gets the Save As box.
void DialogController::startSave(size_t tabIndex) {
    EditorController* ed = EditorController::instance();
    ed->tabs().select(tabIndex);
    ed->sendChar('s', true, false, false);
}

// Runs after every change: finishes "save, then close" and "save everything, then quit".
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

    while (m_quitAfterSave) {
        size_t dirty = tabs.count();
        for (size_t i = 0; i < tabs.count(); ++i)
            if (tabs.modified(i)) { dirty = i; break; }
        if (dirty == tabs.count()) {                           // everything is saved
            m_quitAfterSave = false;
            quitApp();
            break;
        }
        const int id = tabs.at(dirty).id;
        if (id == m_quitTriedId) {                             // we tried this one already: cancelled or failed
            m_quitAfterSave = false;
            st.status = "quit cancelled";
            ed->changedOutside(false);
            break;
        }
        m_quitTriedId = id;
        startSave(dirty);
        if (st.mode == InputMode::Prompt) break;               // wait for the file name
    }

    m_advancing = false;
}
