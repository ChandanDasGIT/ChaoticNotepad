#include "wrapper/editor/editorcontroller.h"
#include <algorithm>
#include <QClipboard>
#include <QGuiApplication>
#include <QJSEngine>
#include <QQmlEngine>
#include <QVariantMap>
#include "wrapper/dialog/dialogcontroller.h"
#include "wrapper/shortcuts/shortcutscontroller.h"

namespace {
const size_t kStickyJumpGap = 3;   // text rows between the pinned lines and a header you jumped to
}

EditorController::EditorController(QObject* parent) : QObject(parent), m_rows(this) {
    static int count = 0;
    if (++count > 1) qWarning("EditorController was created twice: QML and the wrappers are using different objects"); 
    rebuild(true);
}

EditorController* EditorController::instance() {
    static EditorController* inst = new EditorController();
    return inst;
}

EditorController* EditorController::create(QQmlEngine*, QJSEngine*) {
    EditorController* inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);   // QML must not delete it
    return inst;
}

// ------------------------------------------------------------------ helpers

Input::Mods EditorController::toMods(int modifiers) {
    Input::Mods m;
    m.shift = modifiers & Qt::ShiftModifier;
    m.alt = modifiers & Qt::AltModifier;
    m.ctrl = modifiers & Qt::ControlModifier;
    return m;
}

void EditorController::setStatus(const std::string& s) {
    QString q = QString::fromStdString(s);
    if (q == m_status) return;
    m_status = q;
    emit statusChanged();
}

// ------------------------------------------------------------------ the view

void EditorController::viewportChanged(int columns, int visibleRows, int firstRow) {
    const size_t cols = static_cast<size_t>(std::max(columns, 1));
    const size_t vrows = static_cast<size_t>(std::max(visibleRows, 1));
    const size_t first = static_cast<size_t>(std::max(firstRow, 0));

    const bool sizeChanged = cols != m_columns;
    m_columns = cols;
    m_viewRows = vrows;
    m_firstRow = first;
    m_tabs.current().scrollTop = first;

    if (sizeChanged) rebuild(true);
    else updateSticky();
}

// Works out the rows again. Cheap when nothing changed: the engine's revision number tells.
void EditorController::rebuild(bool force) {
    EditorTab& tab = m_tabs.current();
    const unsigned long long rev = tab.view.stateRevision();
    if (!force && m_built && tab.id == m_lastTabId && rev == m_lastRevision && m_columns == m_lastColumns)
        return;

    const TextBuffer& b = tab.view.buffer();
    tab.gutter.update(b);
    tab.syntax.update(b);
    m_stickyScroll.setRegionsFromFolds(tab.view.folding().regions(), b);

    const size_t room = m_columns > 1 ? m_columns - 1 : 1;     // one cell is kept for the cursor at the end of a line
    const size_t rowsBefore = m_builder.rowCount();
    m_builder.update(tab, room);
    const size_t rowsAfter = m_builder.rowCount();
    const size_t rowsDiff = rowsAfter > rowsBefore ? rowsAfter - rowsBefore : rowsBefore - rowsAfter;
    const bool bigChange = m_built && tab.id == m_lastTabId && rowsDiff > 1;   // the row lists start again (see EditorRowsModel::refresh)
    m_rows.refresh(&m_builder, &tab);

    m_lastTabId = tab.id;
    m_lastRevision = tab.view.stateRevision();
    m_lastColumns = m_columns;
    m_built = true;

    updateSticky();
    emit rowsRebuilt();
    if (bigChange) emit scrollRequested(static_cast<int>(m_firstRow));   // a list that starts again goes back to the top: put it back
}

void EditorController::updateSticky() {
    const EditorTab& tab = m_tabs.current();
    const size_t most = m_viewRows > 1 ? std::min(m_stickyScroll.maxLines(), m_viewRows - 1) : 0;
    m_stickyRows = m_builder.sticky(tab, m_stickyScroll, m_firstRow, most);

    QVariantList list;
    for (const StickyRow& s : m_stickyRows) {
        QVariantMap m;
        m["row"] = static_cast<int>(s.row);
        m["lineNumber"] = s.lineNumber;
        m["length"] = s.length;
        m["spans"] = EditorRowsModel::spansToVariant(s.spans);
        list.append(m);
    }
    if (list != m_sticky) {
        m_sticky = list;
        emit stickyChanged();
    }
    emit viewChanged();
}

void EditorController::scrollToRow(size_t row) {
    m_firstRow = row;
    m_tabs.current().scrollTop = row;
    m_tabs.current().followCursor = false;
    emit scrollRequested(static_cast<int>(row));
    updateSticky();
}

// Scrolls (through the text area) so the main cursor is on screen and not under a pinned line.
void EditorController::revealCursor() {
    const size_t vh = std::max<size_t>(m_viewRows, 1);
    const size_t mrow = m_builder.mainCursorRow();
    size_t top = m_firstRow;
    if (mrow < top) top = mrow;
    else if (mrow >= top + vh) top = mrow - vh + 1;
    top = m_stickyScroll.scrollTopToRevealRow(m_builder.rowLines(), top, mrow, vh);
    if (top != m_firstRow) {
        m_firstRow = top;
        m_tabs.current().scrollTop = top;
        emit scrollRequested(static_cast<int>(top));
        updateSticky();
    }
}

// ------------------------------------------------------------------ events

void EditorController::feed(const Input::Event& ev, bool reveal) {
    EditorTab& tab = m_tabs.current();
    if (ev.type != Input::Event::Type::Mouse) m_quitArmed = false;

    m_state.clipboard = QGuiApplication::clipboard()->text().toStdString();   // so Ctrl+V pastes what is on the system clipboard
    m_state.pageRows = m_viewRows;
    m_state.filePath = tab.doc.path();
    m_state.fileName = tab.doc.name();
    m_state.modified = false;       // unsaved-changes warnings are handled here with the tabs, not by the input handler

    const std::vector<Cursor> before = tab.view.cursors();
    handleEvent(ev, tab.view, m_state);

    const std::vector<Cursor>& after = tab.view.cursors();
    bool moved = after.size() != before.size();
    for (size_t i = 0; !moved && i < after.size(); ++i)
        moved = after[i].pos.line != before[i].pos.line || after[i].pos.col != before[i].pos.col ||
                after[i].anchor.line != before[i].anchor.line || after[i].anchor.col != before[i].anchor.col;

    std::vector<Request> requests;
    requests.swap(m_state.requests);
    const int tabBefore = tab.id;
    carryOut(requests);                  // may save, open, close or switch tabs: `tab` is not used after this
    setStatus(m_state.status);

    if (m_tabs.current().id != tabBefore && m_state.mode != InputMode::Edit)
        refreshFind(m_tabs.current().view, m_state);     // the find bar is open: search again in the new tab
    rebuild(true);
    if (m_tabs.current().id != tabBefore) {
        emit scrollRequested(static_cast<int>(m_tabs.current().scrollTop));   // a different tab: back to where it was
        m_firstRow = m_tabs.current().scrollTop;
        updateSticky();
    } else if (reveal && moved) {
        revealCursor();
    }
    emit documentChanged();
}

void EditorController::sendChar(char letter, bool ctrl, bool shift, bool alt) {
    Input::KeyEvent k;
    k.key = Input::Key::Char;
    k.ch = static_cast<char32_t>(letter);
    k.mods.ctrl = ctrl;
    k.mods.shift = shift;
    k.mods.alt = alt;
    feed(Input::Event::makeKey(k), true);
}

void EditorController::send(const Input::Event& ev) { feed(ev, false); }

void EditorController::save() { sendChar('s', true, false, false); }     // a file without a name opens the Save As box
void EditorController::undo() { sendChar('z', true, false, false); }
void EditorController::redo() { sendChar('z', true, true, false); }

std::string EditorController::saveTab(EditorTab& tab) {
    std::string msg;
    if (tab.doc.save(tab.view, msg)) tab.gutter.markSaved(tab.view.buffer());
    return msg;
}

void EditorController::changedOutside(bool reveal) {
    const bool tabChanged = m_tabs.current().id != m_lastTabId;      // another tab was selected, opened or closed
    if (tabChanged && m_state.mode != InputMode::Edit)
        refreshFind(m_tabs.current().view, m_state);                 // the find bar is open: search again in this tab
    setStatus(m_state.status);
    rebuild(true);
    if (tabChanged) {
        m_firstRow = m_tabs.current().scrollTop;                     // back to where this tab was scrolled
        emit scrollRequested(static_cast<int>(m_firstRow));
        updateSticky();
    } else if (reveal) {
        revealCursor();
    }
    emit documentChanged();
}

void EditorController::carryOut(std::vector<Request>& requests) {
    using K = Request::Kind;
    for (const Request& r : requests)
        if (r.kind == K::CopyToClipboard)
            QGuiApplication::clipboard()->setText(QString::fromStdString(r.text));
    for (const Request& r : requests) {
        if (r.kind == K::SaveFile) saveCurrent();
        else if (r.kind == K::SaveFileAs) saveCurrentAs(r.text);
        else if (r.kind == K::OpenFile) {
            std::string msg;
            m_tabs.openFile(r.text, msg);
            m_state.status = msg;
        }
    }
    for (const Request& r : requests) applyAppCommand(r);   // these can close or switch tabs
}

void EditorController::saveCurrent() {
    EditorTab& tab = m_tabs.current();
    if (tab.doc.checkDisk() == Document::DiskState::Changed) {          // someone else changed the file meanwhile: ask
        DialogController::instance()->showSaveConflict(tab.id, tab.doc.name());
        m_state.status = "file changed on disk - choose Overwrite or Cancel";
        return;
    }
    m_state.status = saveTab(tab);
}

void EditorController::saveCurrentAs(const std::string& path) {
    EditorTab& tab = m_tabs.current();
    std::string msg;
    if (tab.doc.saveAs(path, tab.view, msg)) {
        tab.gutter.markSaved(tab.view.buffer());
        tab.syntax.setLanguageFor(path);
        tab.view.setFoldLanguage(path);
    }
    m_state.status = msg;
}

void EditorController::applyAppCommand(const Request& r) {
    using K = Request::Kind;
    switch (r.kind) {
    case K::Quit: DialogController::instance()->requestQuit(); break;
    case K::NewTab: m_tabs.newTab(); m_state.status = "new tab"; break;
    case K::CloseTab: DialogController::instance()->requestClose(m_tabs.currentIndex()); break;
    case K::NextTab: m_tabs.next(); break;
    case K::PrevTab: m_tabs.prev(); break;
    case K::GotoTab:
        if (r.number >= 0 && static_cast<size_t>(r.number) < m_tabs.count()) m_tabs.select(static_cast<size_t>(r.number));
        else m_state.status = "no tab " + std::to_string(r.number + 1);
        break;
    case K::GotoLastTab: m_tabs.selectLast(); break;
    case K::ReopenTab: {
        std::string msg;
        m_tabs.reopenClosed(msg);
        m_state.status = msg;
        break;
    }
    case K::MoveTabLeft:
    case K::MoveTabRight: {
        const size_t i = m_tabs.currentIndex();
        const size_t to = r.kind == K::MoveTabLeft ? (i > 0 ? i - 1 : 0) : std::min(i + 1, m_tabs.count() - 1);
        if (to != i) m_tabs.move(i, to);
        break;
    }
    default: break;   // the minimap and scroll requests come from components that are not built yet
    }
}

// ------------------------------------------------------------------ keyboard

bool EditorController::keyPressed(int key, const QString& text, int modifiers) {
    switch (key) {
    case Qt::Key_Shift: case Qt::Key_Control: case Qt::Key_Alt: case Qt::Key_Meta:
    case Qt::Key_AltGr: case Qt::Key_CapsLock: case Qt::Key_NumLock: case Qt::Key_unknown:
        return false;
    default: break;
    }

    // a shortcut the user changed: the key becomes the engine's own key for that action (or nothing at all)
    int remappedKey = key;
    int remappedMods = modifiers;
    const ShortcutsController::Remap result = ShortcutsController::instance()->remap(remappedKey, remappedMods);
    if (result == ShortcutsController::Remap::Blocked) return true;
    if (result == ShortcutsController::Remap::Remapped) { key = remappedKey; modifiers = remappedMods; }

    Input::KeyEvent k;
    k.mods = toMods(modifiers);
    bool command = true;

    switch (key) {
    case Qt::Key_Return: case Qt::Key_Enter: k.key = Input::Key::Enter; break;
    case Qt::Key_Backspace: k.key = Input::Key::Backspace; break;
    case Qt::Key_Delete: k.key = Input::Key::Delete; break;
    case Qt::Key_Tab: k.key = Input::Key::Tab; break;
    case Qt::Key_Backtab: k.key = Input::Key::Tab; k.mods.shift = true; break;
    case Qt::Key_Escape: k.key = Input::Key::Escape; break;
    case Qt::Key_Insert: k.key = Input::Key::Insert; break;
    case Qt::Key_Up: k.key = Input::Key::Up; break;
    case Qt::Key_Down: k.key = Input::Key::Down; break;
    case Qt::Key_Left: k.key = Input::Key::Left; break;
    case Qt::Key_Right: k.key = Input::Key::Right; break;
    case Qt::Key_Home: k.key = Input::Key::Home; break;
    case Qt::Key_End: k.key = Input::Key::End; break;
    case Qt::Key_PageUp: k.key = Input::Key::PageUp; break;
    case Qt::Key_PageDown: k.key = Input::Key::PageDown; break;
    default:
        if (key >= Qt::Key_F1 && key <= Qt::Key_F12) {
            k.key = Input::Key::Function;
            k.ch = static_cast<char32_t>(key - Qt::Key_F1 + 1);
        } else if ((k.mods.ctrl || k.mods.alt) && key >= 0x20 && key <= 0x7e) {
            k.key = Input::Key::Char;                       // a command: the key without shift, letters in lower case
            k.ch = static_cast<char32_t>(key >= 'A' && key <= 'Z' ? key + 32 : key);
        } else {
            command = false;
        }
    }

    if (command) {
        feed(Input::Event::makeKey(k), true);
        return true;
    }

    // typing: anything printable (accents and input methods arrive here as text too)
    if (!text.isEmpty() && text.at(0).unicode() >= 0x20 && text.at(0).unicode() != 0x7f) {
        feed(Input::Event::makeText(text.toUtf8().toStdString()), true);
        return true;
    }
    return false;
}

// ------------------------------------------------------------------ mouse

void EditorController::mousePress(int row, int cell, int button, int modifiers, int clicks) {
    if (row < 0 || static_cast<size_t>(row) >= m_builder.rowCount()) return;
    Input::MouseEvent m;
    m.kind = Input::MouseEvent::Kind::Press;
    m.button = button == Qt::RightButton ? Input::Button::Right
             : button == Qt::MiddleButton ? Input::Button::Middle : Input::Button::Left;
    m.mods = toMods(modifiers);
    m.region = Input::Region::Text;
    m.pos = m_builder.positionAt(m_tabs.current(), static_cast<size_t>(row), static_cast<size_t>(std::max(cell, 0)));
    m.clicks = clicks;
    feed(Input::Event::makeMouse(m), false);
}

void EditorController::mouseDrag(int row, int cell) {
    if (row < 0 || static_cast<size_t>(row) >= m_builder.rowCount()) return;
    Input::MouseEvent m;
    m.kind = Input::MouseEvent::Kind::Drag;
    m.button = Input::Button::Left;
    m.region = Input::Region::Text;
    m.pos = m_builder.positionAt(m_tabs.current(), static_cast<size_t>(row), static_cast<size_t>(std::max(cell, 0)));
    feed(Input::Event::makeMouse(m), false);
}

void EditorController::mouseRelease() {
    Input::MouseEvent m;
    m.kind = Input::MouseEvent::Kind::Release;
    m.button = Input::Button::Left;
    m.region = Input::Region::Text;
    feed(Input::Event::makeMouse(m), false);
}

void EditorController::toggleFold(int row) {
    const std::vector<size_t>& lines = m_builder.rowLines();
    if (row < 0 || static_cast<size_t>(row) >= lines.size()) return;
    Input::MouseEvent m;
    m.kind = Input::MouseEvent::Kind::Press;
    m.button = Input::Button::Left;
    m.region = Input::Region::FoldMarker;
    m.pos = Position{lines[static_cast<size_t>(row)], 0};
    feed(Input::Event::makeMouse(m), false);
}

// A click on a pinned line: scroll so that header sits a few rows below the pinned lines, and put the cursor on it.
void EditorController::stickyClicked(int index) {
    if (index < 0 || static_cast<size_t>(index) >= m_stickyRows.size()) return;
    const size_t line = static_cast<size_t>(m_stickyRows[static_cast<size_t>(index)].lineNumber) - 1;
    const std::vector<size_t>& rl = m_builder.rowLines();
    if (rl.empty()) return;

    const size_t ri = m_builder.firstRowOfLine(line);
    const size_t most = m_viewRows > 1 ? m_viewRows - 1 : 0;
    auto pinsShown = [&](size_t top) {
        const size_t end = std::min(rl.size(), top + m_stickyScroll.maxLines() + 1);
        std::vector<size_t> v(rl.begin() + static_cast<long>(std::min(top, rl.size())), rl.begin() + static_cast<long>(end));
        return std::min(m_stickyScroll.compute(v).size(), most);
    };

    size_t best = 0, bestDiff = 0;
    bool found = false;
    for (size_t k = 0; k <= m_stickyScroll.maxLines(); ++k) {
        const size_t need = k + kStickyJumpGap;
        const size_t top = ri > need ? ri - need : 0;
        const size_t shown = pinsShown(top);
        const size_t diff = shown > k ? shown - k : k - shown;
        if (!found || diff < bestDiff) { found = true; bestDiff = diff; best = top; }
        if (diff == 0) break;
    }

    m_tabs.current().view.moveCursor(Position{line, 0});
    rebuild(true);
    m_firstRow = best;
    m_tabs.current().scrollTop = best;
    emit scrollRequested(static_cast<int>(best));
    updateSticky();
    emit documentChanged();
}

// ------------------------------------------------------------------ files dropped on the window

void EditorController::openUrls(const QList<QUrl>& urls) {
    std::vector<std::string> paths;
    for (const QUrl& u : urls)
        if (u.isLocalFile()) paths.push_back(u.toLocalFile().toStdString());
    if (paths.empty()) return;
    std::string msg;
    m_tabs.openFiles(paths, msg);
    setStatus(msg);
    rebuild(true);
    emit scrollRequested(static_cast<int>(m_tabs.current().scrollTop));
    m_firstRow = m_tabs.current().scrollTop;
    updateSticky();
    emit documentChanged();
}
