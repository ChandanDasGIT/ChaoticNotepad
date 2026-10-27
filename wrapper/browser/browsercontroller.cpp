#include "wrapper/browser/browsercontroller.h"
#include <QVariantMap>
#include "wrapper/editor/editorcontroller.h"

BrowserController::BrowserController(QObject* parent) : QObject(parent) {
    connect(EditorController::instance(), &EditorController::documentChanged, this, &BrowserController::sync);
    sync();
}

void BrowserController::sync() {
    const InputState& st = EditorController::instance()->inputState();
    const FileBrowser& fb = st.browser;
    const bool open = st.mode == InputMode::Prompt;

    bool dirty = open != m_open;
    m_open = open;
    if (!open) {                                    // nothing to show: keep the old texts, they are hidden
        if (dirty) emit changed();
        return;
    }

    auto set = [&dirty](QString& field, const std::string& value) {
        const QString q = QString::fromStdString(value);
        if (q != field) { field = q; dirty = true; }
    };
    set(m_title, fb.title());
    set(m_actionLabel, fb.mode() == FileBrowser::Mode::Open ? "Open" : "Save");
    set(m_directory, fb.shownDirectory());
    set(m_fieldLabel, fb.fieldLabel());
    set(m_name, fb.name());
    set(m_empty, fb.emptyMessage());
    set(m_error, fb.error());
    set(m_hint, fb.hint());

    const int selected = static_cast<int>(fb.selectedRow());
    if (selected != m_selected) { m_selected = selected; dirty = true; }
    if (fb.listHasFocus() != m_listFocus) { m_listFocus = fb.listHasFocus(); dirty = true; }
    if (fb.showHidden() != m_hidden) { m_hidden = fb.showHidden(); dirty = true; }

    // the list is built again only when the folder, the filter or the hidden files changed
    const QString key = QString::fromStdString(fb.directory()) + '|' + QString::fromStdString(fb.name()) + '|' +
                        QString::number(fb.rowCount()) + '|' + (fb.showHidden() ? '1' : '0');
    if (key != m_key) {
        m_key = key;
        QVariantList entries;
        for (size_t i = 0; i < fb.rowCount(); ++i) {
            QVariantMap m;
            m["name"] = QString::fromStdString(fb.rowName(i));
            m["isDir"] = fb.rowIsDir(i);
            entries.append(m);
        }
        m_entries = entries;
        dirty = true;
    }
    if (dirty) emit changed();
}

void BrowserController::openFile() { EditorController::instance()->sendChar('o', true, false, false); }
void BrowserController::saveFileAs() { EditorController::instance()->sendChar('s', false, false, true); }

void BrowserController::setVisibleRows(int rows) {
    EditorController::instance()->inputState().browser.setVisibleRows(rows);
}

bool BrowserController::keyPressed(int key, const QString& text, int modifiers) {
    return EditorController::instance()->keyPressed(key, text, modifiers);   // the engine knows what each key does in the browser
}

void BrowserController::click(int row) {
    Input::MouseEvent m;
    m.kind = Input::MouseEvent::Kind::Press;
    m.button = Input::Button::Left;
    m.region = Input::Region::Browser;
    m.row = row;
    EditorController::instance()->send(Input::Event::makeMouse(m));
}

void BrowserController::activate() { EditorController::instance()->keyPressed(Qt::Key_Return, QString(), 0); }
void BrowserController::cancel() { EditorController::instance()->keyPressed(Qt::Key_Escape, QString(), 0); }

void BrowserController::goUp() {
    EditorController* ed = EditorController::instance();
    ed->inputState().browser.goUp();
    ed->changedOutside(false);
}

void BrowserController::toggleHidden() {
    EditorController* ed = EditorController::instance();
    ed->inputState().browser.toggleHidden();
    ed->changedOutside(false);
}
