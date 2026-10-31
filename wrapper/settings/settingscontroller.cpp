#include "wrapper/settings/settingscontroller.h"
#include <algorithm>
#include <QSettings>
#include <QTimer>
#include "wrapper/editor/editorcontroller.h"

namespace {
QSettings& file() {
    static QSettings s(QStringLiteral("ChaoticNotepad"), QStringLiteral("ChaoticNotepad"));
    return s;
}
}

SettingsController::SettingsController(QObject* parent) : QObject(parent) {
    QSettings& s = file();
    m_dark = s.value("darkTheme", m_dark).toBool();
    m_fontFamily = s.value("fontFamily", m_fontFamily).toString();
    m_fontSize = std::clamp(s.value("fontSize", m_fontSize).toInt(), 8, 32);
    m_indentWidth = std::clamp(s.value("indentWidth", m_indentWidth).toInt(), 1, 16);
    m_useTabs = s.value("useTabs", m_useTabs).toBool();
    m_autoClose = s.value("autoCloseBrackets", m_autoClose).toBool();
    m_hidePointer = s.value("hidePointerWhileTyping", m_hidePointer).toBool();

    EditorController* ed = EditorController::instance();
    ed->inputState().minimapOn = s.value("showMinimap", true).toBool();
    m_lastMinimap = ed->inputState().minimapOn;

    // tabs are opened and closed all the time, and Alt+M can change the minimap: look after every change
    connect(ed, &EditorController::documentChanged, this, [this] {
        applyToTabs();
        syncMinimap();
    });
    applyToTabs();
}

bool SettingsController::showMinimap() const {
    return EditorController::instance()->inputState().minimapOn;
}

void SettingsController::store() {
    QSettings& s = file();
    s.setValue("darkTheme", m_dark);
    s.setValue("fontFamily", m_fontFamily);
    s.setValue("fontSize", m_fontSize);
    s.setValue("indentWidth", m_indentWidth);
    s.setValue("useTabs", m_useTabs);
    s.setValue("autoCloseBrackets", m_autoClose);
    s.setValue("hidePointerWhileTyping", m_hidePointer);
    s.setValue("showMinimap", showMinimap());
    s.sync();
}

void SettingsController::applyToTabs() {
    TabManager& tabs = EditorController::instance()->tabs();
    IndentStyle style;
    style.useTabs = m_useTabs;
    style.width = static_cast<size_t>(m_indentWidth);
    bool changedAny = false;
    for (size_t i = 0; i < tabs.count(); ++i) {
        TextView& v = tabs.at(i).view;
        const bool fileDecides = tabs.at(i).doc.hasOwnIndent();
        if (!fileDecides && (v.indent().useTabs != style.useTabs || v.indent().width != style.width)) { v.setIndent(style); changedAny = true; }
        if (v.autoClose() != m_autoClose) { v.setAutoClose(m_autoClose); changedAny = true; }
    }
    // tell the status bar (and the rest) once, after this call has finished; the second pass changes nothing, so it stops there
    if (changedAny) QTimer::singleShot(0, this, [] { EditorController::instance()->changedOutside(false); });
}

void SettingsController::overrideFileIndent() {
    TabManager& tabs = EditorController::instance()->tabs();
    for (size_t i = 0; i < tabs.count(); ++i) tabs.at(i).doc.clearOwnIndent();
    applyToTabs();
}

void SettingsController::syncMinimap() {
    const bool now = showMinimap();
    if (now == m_lastMinimap) return;
    m_lastMinimap = now;
    store();
    emit changed();
}

void SettingsController::setDarkTheme(bool on) {
    if (on == m_dark) return;
    m_dark = on;
    store();
    emit changed();
}

void SettingsController::setFontFamily(const QString& name) {
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == m_fontFamily) return;
    m_fontFamily = trimmed;
    store();
    emit changed();
}

void SettingsController::setFontSize(int size) {
    size = std::clamp(size, 8, 32);
    if (size == m_fontSize) return;
    m_fontSize = size;
    store();
    emit changed();
}

void SettingsController::setIndentWidth(int width) {
    width = std::clamp(width, 1, 16);
    if (width == m_indentWidth) return;
    m_indentWidth = width;
    overrideFileIndent();
    store();
    emit changed();
}

void SettingsController::setUseTabs(bool on) {
    if (on == m_useTabs) return;
    m_useTabs = on;
    overrideFileIndent();
    store();
    emit changed();
}

void SettingsController::setAutoCloseBrackets(bool on) {
    if (on == m_autoClose) return;
    m_autoClose = on;
    applyToTabs();
    store();
    emit changed();
}

void SettingsController::setHidePointerWhileTyping(bool on) {
    if (on == m_hidePointer) return;
    m_hidePointer = on;
    store();
    emit changed();
}

void SettingsController::setShowMinimap(bool on) {
    EditorController* ed = EditorController::instance();
    if (ed->inputState().minimapOn == on) return;
    ed->inputState().minimapOn = on;
    ed->changedOutside(false);          // tells the minimap; syncMinimap() remembers it
}
