#include "wrapper/find/findcontroller.h"
#include "textengine/findpanel/findpanel.h"
#include "wrapper/editor/editorcontroller.h"

namespace {

std::string escapeRegex(const std::string& s) {
    const std::string special = "\\^$.|?*+()[]{}";
    std::string out;
    for (char c : s) {
        if (special.find(c) != std::string::npos) out += '\\';
        out += c;
    }
    return out;
}

FindOptions optionsOf(const InputState& st) {
    FindOptions o;
    o.matchCase = st.findCase;
    o.wholeWord = st.findWord;
    o.regex = st.findRegex;
    o.inSelection = st.findInSel;
    return o;
}

bool findIsOn(const InputState& st) {
    return st.mode == InputMode::Find || st.mode == InputMode::Replace;
}

}

FindController::FindController(QObject* parent) : QObject(parent) {
    // The engine can open or close the bar by itself (Ctrl+F, Esc in the text), so follow it after every event.
    connect(EditorController::instance(), &EditorController::documentChanged, this, &FindController::sync);
    sync();
}

// ------------------------------------------------------------------ state

void FindController::sync() {
    EditorController* ed = EditorController::instance();
    const InputState& st = ed->inputState();
    const TextView& view = ed->tab().view;

    const bool open = findIsOn(st);
    const bool replaceOpen = st.mode == InputMode::Replace;
    const QString findText = QString::fromStdString(st.findText);
    const QString replaceText = QString::fromStdString(st.replaceText);

    FindPanel::Info info;
    info.findText = st.findText;
    info.replaceText = st.replaceText;
    info.replaceOpen = replaceOpen;
    info.matchCase = st.findCase;
    info.wholeWord = st.findWord;
    info.regex = st.findRegex;
    info.inSelection = st.findInSel && view.findScoped();
    info.count = view.findMatchCount();
    info.current = view.findCurrent();
    info.error = view.findError();
    const QString counter = open ? QString::fromStdString(FindPanel::counterText(info)) : QString();
    const bool counterError = open && FindPanel::counterIsError(info);

    const bool openFlipped = open != m_open;
    const bool changed = replaceOpen != m_replaceOpen || findText != m_findText || replaceText != m_replaceText ||
                         st.findCase != m_case || st.findWord != m_word || st.findRegex != m_regex ||
                         info.inSelection != m_inSel || counter != m_counter || counterError != m_counterError;

    m_open = open;
    m_replaceOpen = replaceOpen;
    m_findText = findText;
    m_replaceText = replaceText;
    m_case = st.findCase;
    m_word = st.findWord;
    m_regex = st.findRegex;
    m_inSel = info.inSelection;
    m_counter = counter;
    m_counterError = counterError;

    if (changed) emit stateChanged();
    if (openFlipped) {
        emit openChanged();
        if (open) emit focusFind();        // the keyboard goes to the find field
    }
}

void FindController::search() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    ed->tab().view.findSetQuery(st.findText, optionsOf(st));
}

void FindController::finish(bool reveal) {
    EditorController::instance()->changedOutside(reveal);   // works the rows out again; this object syncs on the signal
}

// ------------------------------------------------------------------ opening and closing

void FindController::openWith(bool withReplace) {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    TextView& view = ed->tab().view;

    if (st.mode == InputMode::Edit) {
        view.findOpen();
        st.findInSel = false;
        if (view.hasSelection()) {
            const std::string sel = view.selectedText();
            if (sel.find('\n') == std::string::npos) st.findText = st.findRegex ? escapeRegex(sel) : sel;   // start with the selected text
            else st.findInSel = true;                                                                          // several lines: search inside them
        }
    }
    st.mode = withReplace ? InputMode::Replace : InputMode::Find;
    st.replaceFieldActive = false;
    st.editorFocus = false;
    search();
    finish(true);
    if (withReplace) emit focusReplace(); else emit focusFind();
}

void FindController::openFind() { openWith(false); }
void FindController::openReplace() { openWith(true); }

void FindController::toggleReplace() {
    InputState& st = EditorController::instance()->inputState();
    if (st.mode == InputMode::Edit) { openWith(true); return; }
    st.mode = st.mode == InputMode::Replace ? InputMode::Find : InputMode::Replace;
    st.replaceFieldActive = false;
    finish(false);
}

void FindController::close() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    st.mode = InputMode::Edit;
    st.editorFocus = false;
    st.replaceFieldActive = false;
    st.findInSel = false;
    ed->tab().view.clearFind();
    st.status = "find closed";
    finish(false);
}

// ------------------------------------------------------------------ searching

void FindController::setFindText(const QString& text) {
    InputState& st = EditorController::instance()->inputState();
    st.findText = text.toStdString();
    st.editorFocus = false;
    search();
    finish(true);
}

void FindController::setReplaceText(const QString& text) {
    EditorController::instance()->inputState().replaceText = text.toStdString();
    sync();
}

// After a step to the next / previous match: say so in the status bar when the search went round the end of the file.
static void noteWrap(InputState& st, const TextView& view, int before, bool forward) {
    const int after = view.findCurrent();
    const bool wrapped = view.findMatchCount() > 0 && before >= 0 && (forward ? after <= before : after >= before);
    if (wrapped) st.status = "Search wrapped";
    else if (st.status == "Search wrapped") st.status.clear();
}

void FindController::next() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    TextView& view = ed->tab().view;
    st.editorFocus = false;
    const int before = view.findCurrent();
    view.findNext();
    noteWrap(st, view, before, true);
    finish(true);
}

void FindController::prev() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    TextView& view = ed->tab().view;
    st.editorFocus = false;
    const int before = view.findCurrent();
    view.findPrev();
    noteWrap(st, view, before, false);
    finish(true);
}

void FindController::selectAll() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    TextView& view = ed->tab().view;
    if (!view.selectAllMatches()) {
        st.status = "no matches";
        finish(false);
        return;
    }
    st.status = std::to_string(view.cursorCount()) + " cursors on all matches";
    st.mode = InputMode::Edit;                 // like the terminal version: the bar closes and the cursors stay
    st.editorFocus = false;
    st.replaceFieldActive = false;
    st.findInSel = false;
    view.clearFind();
    finish(true);
}

void FindController::replaceCurrent() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    TextView& view = ed->tab().view;

    // the engine replaces the match the cursor is on: put the cursor on the one the counter shows as current
    const int current = view.findCurrent();
    const std::vector<Range>& matches = view.findMatches();
    if (current >= 0 && static_cast<size_t>(current) < matches.size())
        view.select(matches[current].from, matches[current].to);

    const bool done = view.replaceCurrent(st.replaceText);
    st.status = done ? "replaced" : "nothing to replace";
    finish(true);
}

void FindController::replaceAll() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    const size_t n = ed->tab().view.replaceAll(st.replaceText);
    st.status = "replaced " + std::to_string(n);
    finish(true);
}

// ------------------------------------------------------------------ options

void FindController::toggleCase() {
    InputState& st = EditorController::instance()->inputState();
    st.findCase = !st.findCase;
    search();
    finish(true);
}

void FindController::toggleWord() {
    InputState& st = EditorController::instance()->inputState();
    st.findWord = !st.findWord;
    search();
    finish(true);
}

void FindController::toggleRegex() {
    InputState& st = EditorController::instance()->inputState();
    st.findRegex = !st.findRegex;
    search();
    finish(true);
}

void FindController::toggleSelection() {
    EditorController* ed = EditorController::instance();
    InputState& st = ed->inputState();
    st.findInSel = !st.findInSel;
    search();
    if (st.findInSel && !ed->tab().view.findScoped()) st.status = "select text before opening find to search inside it";
    finish(true);
}
