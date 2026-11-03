#include "wrapper/markdown/markdowncontroller.h"
#include <QJSEngine>
#include <QFileInfo>
#include <QDir>
#include <QQmlEngine>
#include "wrapper/editor/editorcontroller.h"
#include "wrapper/settings/settingscontroller.h"
#include "textengine/markdown/markdownparser.h"

// ---------------------------------------------------------------------------

MarkdownController* MarkdownController::instance() {
    static MarkdownController* inst = new MarkdownController();
    return inst;
}

MarkdownController* MarkdownController::create(QQmlEngine*, QJSEngine*) {
    MarkdownController* inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);
    return inst;
}

MarkdownController::MarkdownController(QObject* parent) : QObject(parent) {
    static int count = 0;
    if (++count > 1)
        qWarning("MarkdownController was created twice: QML and the wrappers are using different objects");

    // When the document changes (text edited, tab switched, file opened), re-render HTML.
    connect(EditorController::instance(), &EditorController::documentChanged,
            this, &MarkdownController::onDocumentChanged);

    // When the theme changes, re-render with the new colour scheme.
    connect(SettingsController::instance(), &SettingsController::changed,
            this, &MarkdownController::onThemeChanged);
}

// ---------------------------------------------------------------------------
// State queries
// ---------------------------------------------------------------------------

bool MarkdownController::isMarkdown() const {
    const LanguageDef* lang = EditorController::instance()->tab().syntax.language();
    return lang && lang->name == "Markdown";
}

// ---------------------------------------------------------------------------
// Slots
// ---------------------------------------------------------------------------

QUrl MarkdownController::baseUrl() const {
    const auto path = QString::fromStdString(EditorController::instance()->tab().doc.path());
    return QUrl::fromLocalFile(QFileInfo(path).absolutePath() + QDir::separator());
}

void MarkdownController::onDocumentChanged() {
    emit stateChanged();
    closeIfNotMarkdown();
    if (isMarkdown() && (m_previewOpen || m_splitOpen))
        rebuild();
}

void MarkdownController::onThemeChanged() {
    if (isMarkdown() && (m_previewOpen || m_splitOpen))
        rebuild();
}

void MarkdownController::rebuild() {
    const bool isDark = SettingsController::instance()->darkTheme();
    const TextBuffer& buf = EditorController::instance()->tab().view.buffer();
    std::vector<std::string> lines;
    lines.reserve(buf.lineCount());
    for (size_t i = 0; i < buf.lineCount(); ++i)
        lines.push_back(buf.line(i));
    const std::string page = MarkdownParser::toPage(lines, isDark);
    m_html = QString::fromStdString(page);
    emit htmlChanged();
}

void MarkdownController::closeIfNotMarkdown() {
    if (!isMarkdown()) {
        bool wasOpen = m_previewOpen || m_splitOpen;
        m_previewOpen = false;
        m_splitOpen   = false;
        if (wasOpen) emit stateChanged();
    }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

void MarkdownController::toggleFullPreview() {
    if (!isMarkdown()) return;
    m_previewOpen = !m_previewOpen;
    m_splitOpen   = false;           // only one mode at a time
    emit stateChanged();
    if (m_previewOpen) rebuild();
}

void MarkdownController::toggleSplitPreview() {
    if (!isMarkdown()) return;
    m_splitOpen   = !m_splitOpen;
    m_previewOpen = false;           // only one mode at a time
    emit stateChanged();
    if (m_splitOpen) rebuild();
}
