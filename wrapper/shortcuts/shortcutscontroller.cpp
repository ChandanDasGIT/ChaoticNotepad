#include "wrapper/shortcuts/shortcutscontroller.h"
#include <QJSEngine>
#include <QKeyCombination>
#include <QKeySequence>
#include <QSettings>
#include <QVariantMap>

namespace {
const int kModMask = Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier | Qt::MetaModifier;

QSettings& file() {
    static QSettings s(QStringLiteral("ChaoticNotepad"), QStringLiteral("ChaoticNotepad"));
    return s;
}
}

ShortcutsController* ShortcutsController::instance() {
    static ShortcutsController* inst = new ShortcutsController();
    return inst;
}

ShortcutsController* ShortcutsController::create(QQmlEngine*, QJSEngine*) {
    ShortcutsController* inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);
    return inst;
}

// ------------------------------------------------------------------ the list of shortcuts

void ShortcutsController::add(const QString& section, const QString& id, const QString& title, int key, int mods) {
    Action a;
    a.id = id;
    a.section = section;
    a.title = title;
    a.builtIn = Combo{key, mods};
    a.current = a.builtIn;
    m_actions.append(a);
}

void ShortcutsController::addFixed(const QString& section, const QString& title, const QString& keys) {
    Action a;
    a.id = QString();
    a.section = section;
    a.title = title;
    a.rebindable = false;
    a.fixedKeys = keys;
    m_actions.append(a);
}

void ShortcutsController::reserve(int key, int mods) { m_reserved.insert(key | mods); }

ShortcutsController::ShortcutsController(QObject* parent) : QObject(parent) {
    static int count = 0;
    if (++count > 1) qWarning("ShortcutsController was created twice: QML and the wrappers are using different objects");

    const int C = Qt::ControlModifier, A = Qt::AltModifier, S = Qt::ShiftModifier;

    const QString files = QStringLiteral("Files and tabs");
    add(files, "open",         "Open a file",                  Qt::Key_O, C);
    add(files, "save",         "Save (Save As for a new file)", Qt::Key_S, C);
    add(files, "saveAs",       "Save As",                      Qt::Key_S, C | S);
    add(files, "saveAsAlt",    "Save As (second shortcut)",    Qt::Key_S, A);
    add(files, "newTab",       "New tab",                      Qt::Key_T, C);
    add(files, "closeTab",     "Close tab",                    Qt::Key_W, C);
    add(files, "nextTab",      "Next tab",                     Qt::Key_Tab, C);
    add(files, "prevTab",      "Previous tab",                 Qt::Key_Tab, C | S);
    add(files, "nextTabAlt",   "Next tab (second shortcut)",   Qt::Key_PageDown, C);
    add(files, "prevTabAlt",   "Previous tab (second shortcut)", Qt::Key_PageUp, C);
    add(files, "reopenTab",    "Reopen the last closed tab",   Qt::Key_T, A);
    add(files, "moveTabLeft",  "Move the tab left",            Qt::Key_PageUp, A | S);
    add(files, "moveTabRight", "Move the tab right",           Qt::Key_PageDown, A | S);
    add(files, "quit",         "Quit",                         Qt::Key_Q, C);
    addFixed(files, "Go to tab 1 to 8", "Alt+1…8");
    addFixed(files, "Go to the last tab", "Alt+9");

    const QString editing = QStringLiteral("Editing");
    add(editing, "undo",          "Undo",                          Qt::Key_Z, C);
    add(editing, "redo",          "Redo",                          Qt::Key_Z, C | S);
    add(editing, "redoAlt",       "Redo (second shortcut)",        Qt::Key_Y, C);
    add(editing, "cut",           "Cut",                           Qt::Key_X, C);
    add(editing, "copy",          "Copy",                          Qt::Key_C, C);
    add(editing, "paste",         "Paste",                         Qt::Key_V, C);
    add(editing, "selectAll",     "Select all",                    Qt::Key_A, C);
    add(editing, "deleteLine",    "Delete the line",               Qt::Key_K, C);
    add(editing, "moveLineUp",    "Move the line up",              Qt::Key_Up, A);
    add(editing, "moveLineDown",  "Move the line down",            Qt::Key_Down, A);
    add(editing, "duplicateUp",   "Duplicate the line above",      Qt::Key_Up, A | S);
    add(editing, "duplicateDown", "Duplicate the line below",      Qt::Key_Down, A | S);
    addFixed(editing, "Delete the word before the cursor", "Ctrl+Backspace");
    addFixed(editing, "Indent", "Tab");
    addFixed(editing, "Outdent", "Shift+Tab");

    const QString moving = QStringLiteral("Moving and selecting");
    addFixed(moving, "Move by word", "Ctrl+Left / Ctrl+Right");
    addFixed(moving, "Start / end of the line", "Home / End");
    addFixed(moving, "Move by page", "PageUp / PageDown");
    addFixed(moving, "Select while moving", "Shift+Arrow keys");

    const QString cursors = QStringLiteral("Several cursors");
    add(cursors, "addNext",     "Add a cursor at the next occurrence of the selected text", Qt::Key_D, C);
    add(cursors, "addAll",      "Add a cursor at every occurrence of the selected text",    Qt::Key_D, C | A);
    add(cursors, "cursorAbove", "Add a cursor above",                                       Qt::Key_Up, C | A);
    add(cursors, "cursorBelow", "Add a cursor below",                                       Qt::Key_Down, C | A);
    addFixed(cursors, "Add a cursor where you click", "Alt+Click");
    addFixed(cursors, "Back to one cursor", "Esc");

    const QString folding = QStringLiteral("Folding");
    add(folding, "fold",      "Fold the block at the cursor",   Qt::Key_BracketLeft, C | A);
    add(folding, "unfold",    "Unfold the block at the cursor", Qt::Key_BracketRight, C | A);
    add(folding, "foldAll",   "Fold all blocks",                Qt::Key_BracketLeft, C | A | S);
    add(folding, "unfoldAll", "Unfold all blocks",              Qt::Key_BracketRight, C | A | S);

    const QString view = QStringLiteral("View");
    add(view, "minimap", "Show or hide the minimap", Qt::Key_M, A);

    const QString find = QStringLiteral("Find and replace");
    add(find, "find",    "Find",                 Qt::Key_F, C);
    add(find, "replace", "Find and replace",     Qt::Key_R, C);
    addFixed(find, "Next match", "Enter");
    addFixed(find, "Previous match", "Shift+Enter");
    addFixed(find, "Close the find bar", "Esc");

    const QString mouse = QStringLiteral("Mouse");
    addFixed(mouse, "Select the word", "Double-click");
    addFixed(mouse, "Select the line", "Triple-click");
    addFixed(mouse, "Fold or unfold", "Click the arrow by a line number");
    addFixed(mouse, "Scroll the text", "Click or drag in the minimap");

    const QString browser = QStringLiteral("File browser (Open and Save As)");
    addFixed(browser, "Move the selection", "Up / Down");
    addFixed(browser, "Go to the parent folder", "Alt+Up");
    addFixed(browser, "Show or hide hidden files", "Alt+H");

    // keys of the fixed shortcuts that a changeable shortcut must not take
    reserve(Qt::Key_Left, Qt::ControlModifier);
    reserve(Qt::Key_Right, Qt::ControlModifier);
    reserve(Qt::Key_Left, Qt::ControlModifier | Qt::ShiftModifier);
    reserve(Qt::Key_Right, Qt::ControlModifier | Qt::ShiftModifier);
    reserve(Qt::Key_Backspace, Qt::ControlModifier);
    reserve(Qt::Key_Delete, Qt::ControlModifier);
    reserve(Qt::Key_H, Qt::AltModifier);
    for (int k = Qt::Key_1; k <= Qt::Key_9; ++k) reserve(k, Qt::AltModifier);

    load();
    rebuild();
}

ShortcutsController::Action* ShortcutsController::find(const QString& id) {
    if (id.isEmpty()) return nullptr;
    for (Action& a : m_actions)
        if (a.id == id) return &a;
    return nullptr;
}

// ------------------------------------------------------------------ keys

// One way to write each key, so that what the user pressed and what is stored can be compared.
void ShortcutsController::normalise(int& key, int& mods) {
    mods &= kModMask;
    if (key == Qt::Key_Backtab) { key = Qt::Key_Tab; mods |= Qt::ShiftModifier; }               // Shift+Tab arrives as Backtab
    else if (key == Qt::Key_BraceLeft) { key = Qt::Key_BracketLeft; mods |= Qt::ShiftModifier; }   // Shift+[ arrives as {
    else if (key == Qt::Key_BraceRight) { key = Qt::Key_BracketRight; mods |= Qt::ShiftModifier; }
}

QStringList ShortcutsController::caps(const Combo& c) {
    QStringList list;
    if (c.mods & Qt::ControlModifier) list << QStringLiteral("Ctrl");
    if (c.mods & Qt::AltModifier) list << QStringLiteral("Alt");
    if (c.mods & Qt::ShiftModifier) list << QStringLiteral("Shift");
    if (c.mods & Qt::MetaModifier) list << QStringLiteral("Meta");
    list << QKeySequence(QKeyCombination(static_cast<Qt::Key>(c.key))).toString(QKeySequence::PortableText);
    return list;
}

// "Ctrl+Tab / Ctrl+PageDown" -> [ ["Ctrl","Tab"], ["Ctrl","PageDown"] ]
QVariantList ShortcutsController::capsOfFixed(const QString& keys) {
    QVariantList ways;
    for (const QString& way : keys.split(QStringLiteral(" / "))) {
        if (way.contains(QLatin1Char(' ')) && !way.contains(QLatin1Char('+')))
            ways.append(QVariant(QStringList{way}));                    // words, not keys: shown as one piece
        else
            ways.append(QVariant(way.split(QLatin1Char('+'))));
    }
    return ways;
}

// ------------------------------------------------------------------ the lookup

void ShortcutsController::rebuild() {
    m_byCode.clear();
    m_blocked.clear();
    for (int i = 0; i < m_actions.size(); ++i)
        if (m_actions[i].rebindable) m_byCode.insert(m_actions[i].current.code(), i);
    for (const Action& a : m_actions)
        if (a.rebindable && !m_byCode.contains(a.builtIn.code())) m_blocked.insert(a.builtIn.code());
}

ShortcutsController::Remap ShortcutsController::remap(int& key, int& modifiers) const {
    int k = key;
    int m = modifiers;
    normalise(k, m);
    const int code = k | m;
    const auto it = m_byCode.constFind(code);
    if (it != m_byCode.constEnd()) {
        const Action& a = m_actions[it.value()];
        key = a.builtIn.key;                       // the engine gets its own key for this action
        modifiers = a.builtIn.mods;
        return Remap::Remapped;
    }
    if (m_blocked.contains(code)) return Remap::Blocked;
    return Remap::None;
}

// ------------------------------------------------------------------ changing

QString ShortcutsController::setShortcut(const QString& id, int key, int modifiers) {
    Action* a = find(id);
    if (!a || !a->rebindable) return QStringLiteral("This shortcut cannot be changed.");

    switch (key) {
    case Qt::Key_Control: case Qt::Key_Alt: case Qt::Key_Shift: case Qt::Key_Meta: case Qt::Key_AltGr:
    case Qt::Key_unknown: case 0:
        return QStringLiteral("Press a key together with Ctrl or Alt.");
    default: break;
    }

    int k = key;
    int m = modifiers;
    normalise(k, m);
    if (m & Qt::MetaModifier) return QStringLiteral("The Meta key cannot be used.");
    if (!(m & (Qt::ControlModifier | Qt::AltModifier))) return QStringLiteral("Use Ctrl or Alt together with the key.");

    const bool printable = k >= 0x21 && k <= 0x7e;
    const bool named = k == Qt::Key_Tab || k == Qt::Key_Up || k == Qt::Key_Down || k == Qt::Key_Left || k == Qt::Key_Right ||
                       k == Qt::Key_Home || k == Qt::Key_End || k == Qt::Key_PageUp || k == Qt::Key_PageDown;
    if (!printable && !named) return QStringLiteral("That key cannot be used for a shortcut.");

    const Combo wanted{k, m};
    if (wanted == a->current) return QString();                       // nothing to do
    if (m_reserved.contains(wanted.code())) return QStringLiteral("That key is used by a fixed shortcut.");
    for (const Action& o : m_actions)
        if (&o != a && o.rebindable && o.current == wanted)
            return QStringLiteral("Already used by \"%1\".").arg(o.title);

    a->current = wanted;
    rebuild();
    store();
    emit changed();
    return QString();
}

void ShortcutsController::reset(const QString& id) {
    Action* a = find(id);
    if (!a || !a->rebindable || a->current == a->builtIn) return;

    // another action may be using this built-in key now: it goes back to its own key as well
    for (Action& o : m_actions)
        if (&o != a && o.rebindable && o.current == a->builtIn) o.current = o.builtIn;
    a->current = a->builtIn;
    rebuild();
    store();
    emit changed();
}

void ShortcutsController::resetAll() {
    if (!anyChanged()) return;
    for (Action& a : m_actions) a.current = a.builtIn;
    rebuild();
    store();
    emit changed();
}

bool ShortcutsController::anyChanged() const {
    for (const Action& a : m_actions)
        if (a.rebindable && !(a.current == a.builtIn)) return true;
    return false;
}

// ------------------------------------------------------------------ saving

void ShortcutsController::store() const {
    QSettings& s = file();
    s.beginGroup(QStringLiteral("shortcuts"));
    s.remove(QString());                                               // forget the old list, then write what differs
    for (const Action& a : m_actions) {
        if (!a.rebindable || a.current == a.builtIn) continue;
        const QKeyCombination combo(Qt::KeyboardModifiers::fromInt(a.current.mods), static_cast<Qt::Key>(a.current.key));
        s.setValue(a.id, QKeySequence(combo).toString(QKeySequence::PortableText));
    }
    s.endGroup();
    s.sync();
}

void ShortcutsController::load() {
    QSettings& s = file();
    s.beginGroup(QStringLiteral("shortcuts"));
    for (const QString& id : s.childKeys()) {
        Action* a = find(id);
        if (!a || !a->rebindable) continue;
        const QKeySequence seq = QKeySequence::fromString(s.value(id).toString(), QKeySequence::PortableText);
        if (seq.count() != 1) continue;
        int k = static_cast<int>(seq[0].key());
        int m = seq[0].keyboardModifiers().toInt();
        normalise(k, m);
        const Combo c{k, m};
        bool taken = m_reserved.contains(c.code());
        for (const Action& o : m_actions)
            if (&o != a && o.rebindable && o.current == c) taken = true;
        if (!taken && (m & (Qt::ControlModifier | Qt::AltModifier))) a->current = c;   // a bad entry is ignored
    }
    s.endGroup();
}

// ------------------------------------------------------------------ what the dialog shows

QVariantList ShortcutsController::sections() const {
    QVariantList result;
    QString lastSection;
    QVariantList items;

    auto flush = [&] {
        if (lastSection.isEmpty()) return;
        QVariantMap sec;
        sec["title"] = lastSection;
        sec["items"] = items;
        result.append(sec);
        items.clear();
    };

    for (const Action& a : m_actions) {
        if (a.section != lastSection) {
            flush();
            lastSection = a.section;
        }
        QVariantMap item;
        item["id"] = a.id;
        item["what"] = a.title;
        item["fixed"] = !a.rebindable;
        if (a.rebindable) {
            item["keys"] = QVariantList{QVariant(caps(a.current))};
            item["defaultKeys"] = QVariantList{QVariant(caps(a.builtIn))};
            item["changed"] = !(a.current == a.builtIn);
        } else {
            item["keys"] = capsOfFixed(a.fixedKeys);
            item["defaultKeys"] = capsOfFixed(a.fixedKeys);
            item["changed"] = false;
        }
        items.append(item);
    }
    flush();
    return result;
}
