#include "wrapper/session/session.h"
#include <algorithm>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QStandardPaths>
#include <memory>
#include "wrapper/editor/editorcontroller.h"
#include "wrapper/settings/settingscontroller.h"

namespace {

bool g_saved = false;

// ~/.local/state/ChaoticNotepad: not ~/.local/share/ChaoticNotepad, which is the program itself in a tarball install
// (installing or updating replaces that folder as a whole)
QString root() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + QStringLiteral("/ChaoticNotepad");
}

// 2.3.4 kept the session in the program's folder: move it once
void moveOldSession() {
    const QString old = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/ChaoticNotepad/session");
    const QString now = root() + QStringLiteral("/session");
    if (!QFileInfo::exists(old + QStringLiteral("/session.json")) || QFileInfo::exists(now)) return;
    QDir().mkpath(root());
    if (!QDir().rename(old, now)) return;
    QFile::remove(QFileInfo(old).path() + QStringLiteral("/session.lock"));
}

// The window that owns the session. A crashed window's lock is noticed as stale (its process is gone).
bool owns() {
    static std::unique_ptr<QLockFile> lock;
    if (!lock) {
        QDir().mkpath(root());
        lock = std::make_unique<QLockFile>(root() + QStringLiteral("/session.lock"));
        lock->setStaleLockTime(0);                       // only a dead process makes it stale, not its age
        // let it go as the program ends, so a new version started by the update can take it at once
        QObject::connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, [] { lock->unlock(); });
    }
    return lock->isLocked() || lock->tryLock(0);
}

int flagsOf(const CharStyle& s) { return (s.bold ? 1 : 0) | (s.italic ? 2 : 0) | (s.underline ? 4 : 0); }

// formatting as [start, length, flags] runs; empty when the text has none
QJsonArray styleRuns(const std::vector<CharStyle>& styles) {
    QJsonArray runs;
    size_t i = 0;
    while (i < styles.size()) {
        const int f = flagsOf(styles[i]);
        size_t j = i + 1;
        while (j < styles.size() && flagsOf(styles[j]) == f) ++j;
        if (f != 0) runs.append(QJsonArray{static_cast<qint64>(i), static_cast<qint64>(j - i), f});
        i = j;
    }
    return runs;
}

std::vector<CharStyle> stylesFrom(const QJsonArray& runs, const std::string& text) {
    if (runs.isEmpty()) return {};
    size_t count = 0;
    for (char c : text)
        if (c != '\n' && c != '\r') ++count;
    std::vector<CharStyle> styles(count);
    for (const QJsonValue& v : runs) {
        const QJsonArray r = v.toArray();
        if (r.size() != 3) continue;
        const qint64 start = r.at(0).toInteger(), length = r.at(1).toInteger();
        const int f = r.at(2).toInt();
        if (start < 0 || length < 0) continue;
        for (size_t k = static_cast<size_t>(start); k < count && k < static_cast<size_t>(start + length); ++k) {
            styles[k].bold = f & 1;
            styles[k].italic = f & 2;
            styles[k].underline = f & 4;
        }
    }
    return styles;
}

bool writeFile(const QString& path, const QByteArray& data) {
    QFile f(path);
    return f.open(QIODevice::WriteOnly | QIODevice::Truncate) && f.write(data) == data.size() && f.flush();
}

}  // namespace

namespace Session {

QString folder() { return root() + QStringLiteral("/session"); }

bool enabled() { return SettingsController::instance()->restoreSession(); }

bool savedForQuit() { return g_saved; }

void clear() {
    for (const QString& name : {QStringLiteral("/session"), QStringLiteral("/session.new"), QStringLiteral("/session.old")})
        QDir(root() + name).removeRecursively();
}

bool saveForQuit() {
    if (!enabled() || !owns()) return false;
    TabManager& tabs = EditorController::instance()->tabs();

    // written next to the old session first, so a failure halfway leaves the old one as it was
    const QString fresh = root() + QStringLiteral("/session.new");
    QDir(fresh).removeRecursively();
    if (!QDir().mkpath(fresh)) return false;
    QFile::setPermissions(fresh, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);

    QJsonArray list;
    int current = 0;
    for (size_t i = 0; i < tabs.count(); ++i) {
        EditorTab& t = tabs.at(i);
        const bool hasText = !t.view.text().empty();
        if (!t.doc.hasPath() && t.label.empty() && !hasText) continue;      // an empty untitled tab
        if (i == tabs.currentIndex()) current = static_cast<int>(list.size());

        QJsonObject o;
        o[QStringLiteral("path")] = QString::fromStdString(t.doc.path());
        o[QStringLiteral("label")] = QString::fromStdString(t.label);
        o[QStringLiteral("untitledNo")] = t.untitledNo;
        const Position p = t.view.cursor();
        o[QStringLiteral("line")] = static_cast<qint64>(p.line);
        o[QStringLiteral("col")] = static_cast<qint64>(p.col);
        o[QStringLiteral("scrollTop")] = static_cast<qint64>(t.scrollTop);

        // unsaved text is kept here; a file without changes is read from disk again
        if (t.doc.modified(t.view) || !t.label.empty()) {
            const QString name = QStringLiteral("tab-%1.txt").arg(list.size());
            const std::string text = t.view.text();
            if (!writeFile(fresh + QLatin1Char('/') + name, QByteArray::fromStdString(text))) return false;
            o[QStringLiteral("text")] = name;
            const QJsonArray runs = styleRuns(t.view.allStyles());
            if (!runs.isEmpty()) o[QStringLiteral("styles")] = runs;
        }
        list.append(o);
    }
    QJsonObject top;
    top[QStringLiteral("version")] = 1;
    top[QStringLiteral("current")] = current;
    top[QStringLiteral("tabs")] = list;
    if (!writeFile(fresh + QStringLiteral("/session.json"), QJsonDocument(top).toJson())) return false;

    const QString old = root() + QStringLiteral("/session.old");
    QDir(old).removeRecursively();
    if (QFileInfo::exists(folder()) && !QDir().rename(folder(), old)) return false;
    if (!QDir().rename(fresh, folder())) {
        QDir().rename(old, folder());
        return false;
    }
    QDir(old).removeRecursively();
    g_saved = true;
    return true;
}

void restore() {
    if (!enabled() || !owns()) return;
    moveOldSession();
    QFile f(folder() + QStringLiteral("/session.json"));
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject top = QJsonDocument::fromJson(f.readAll()).object();
    const QJsonArray list = top.value(QStringLiteral("tabs")).toArray();
    if (list.isEmpty()) return;

    EditorController* ed = EditorController::instance();
    TabManager& tabs = ed->tabs();
    std::vector<int> ids;                                  // the restored tab for each entry (0: none)
    QStringList missing;

    for (const QJsonValue& v : list) {
        const QJsonObject o = v.toObject();
        const QString path = o.value(QStringLiteral("path")).toString();
        const std::string label = o.value(QStringLiteral("label")).toString().toStdString();
        const QString textName = o.value(QStringLiteral("text")).toString();
        std::string text;
        bool hasText = false;
        if (!textName.isEmpty() && !textName.contains(QLatin1Char('/'))) {
            QFile tf(folder() + QLatin1Char('/') + textName);
            if (tf.open(QIODevice::ReadOnly)) { text = tf.readAll().toStdString(); hasText = true; }
        }

        EditorTab* tab = nullptr;
        if (!path.isEmpty() && label.empty()) {
            if (!hasText && !QFileInfo::exists(path)) { missing << QFileInfo(path).fileName(); ids.push_back(0); continue; }
            std::string msg;
            if (tabs.openFile(path.toStdString(), msg)) tab = &tabs.current();
            else if (!hasText) { missing << QFileInfo(path).fileName(); ids.push_back(0); continue; }
        }
        if (!tab) {                                        // untitled, a read-only copy, or a file that no longer opens
            const EditorTab& now = tabs.current();
            const bool reuse = ids.empty() && tabs.count() == 1 && !now.doc.hasPath() && now.label.empty() && now.view.text().empty();
            if (!reuse) tabs.newTab();
            tab = &tabs.current();
            if (!label.empty()) { tab->doc.loadUntitled(text, tab->view); tab->label = label; hasText = false; }
            const int no = o.value(QStringLiteral("untitledNo")).toInt();
            bool used = false;
            for (size_t i = 0; i < tabs.count(); ++i)
                if (&tabs.at(i) != tab && !tabs.at(i).doc.hasPath() && tabs.at(i).untitledNo == no) used = true;
            if (no > 0 && !used) tab->untitledNo = no;
        }
        if (hasText) tab->view.replaceAllText(text, stylesFrom(o.value(QStringLiteral("styles")).toArray(), text));

        Position p;
        p.line = static_cast<size_t>(std::max<qint64>(0, o.value(QStringLiteral("line")).toInteger()));
        p.col = static_cast<size_t>(std::max<qint64>(0, o.value(QStringLiteral("col")).toInteger()));
        tab->view.moveCursor(tab->view.buffer().clamp(p));
        tab->scrollTop = static_cast<size_t>(std::max<qint64>(0, o.value(QStringLiteral("scrollTop")).toInteger()));
        tab->modifiedCache = tab->doc.modified(tab->view);
        ids.push_back(tab->id);
    }

    const int current = top.value(QStringLiteral("current")).toInt();
    if (current >= 0 && current < static_cast<int>(ids.size()) && ids[current] != 0)
        for (size_t i = 0; i < tabs.count(); ++i)
            if (tabs.at(i).id == ids[current]) tabs.select(i);

    InputState& st = ed->inputState();
    const long restored = static_cast<long>(std::count_if(ids.begin(), ids.end(), [](int id) { return id != 0; }));
    st.status = "restored " + std::to_string(restored) + (restored == 1 ? " tab" : " tabs");
    if (!missing.isEmpty()) st.status += "; gone from disk: " + missing.join(QStringLiteral(", ")).toStdString();
    ed->changedOutside(true);
}

}  // namespace Session
