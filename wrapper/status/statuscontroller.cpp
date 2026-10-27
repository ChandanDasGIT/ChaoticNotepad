#include "wrapper/status/statuscontroller.h"
#include "wrapper/editor/editorcontroller.h"
#include <cctype>
#include <string>

StatusController::StatusController(QObject* parent) : QObject(parent) {
    connect(EditorController::instance(), &EditorController::documentChanged, this, &StatusController::sync);
    sync();
}

void StatusController::sync() {
    EditorController* ed = EditorController::instance();
    const EditorTab& tab = ed->tab();
    const TextView& view = tab.view;

    const Position cur = view.cursor();
    const int line = static_cast<int>(cur.line) + 1;
    const int column = static_cast<int>(Utf8::charCount(view.buffer().line(cur.line).substr(0, cur.col))) + 1;
    const int selected = view.anySelection() ? static_cast<int>(view.selectionStats().characters) : 0;
    const int cursors = static_cast<int>(view.cursorCount());

    const IndentStyle& ind = view.indent();
    const QString indent = QString(ind.useTabs ? "TabSpaces: %1" : "Spaces: %1").arg(ind.width);
    const QString encoding = QString::fromStdString(tab.doc.encodingName());
    const QString lineEnding = QString::fromStdString(tab.doc.lineEndingName());
    const QString language = tab.syntax.language() ? QString::fromStdString(tab.syntax.language()->name)
                                                   : QStringLiteral("Plain Text");
    const QString message = QString::fromStdString(ed->inputState().status);

    // lines, words and paragraphs: counted again only when the text or the tab changed
    const TextBuffer& buf = view.buffer();
    if (tab.id != m_countTab || buf.revision() != m_countRev) {
        m_countTab = tab.id;
        m_countRev = buf.revision();
        int wordCount = 0;
        int paragraphCount = 0;
        bool inParagraph = false;
        for (size_t l = 0; l < buf.lineCount(); ++l) {
            bool inWord = false;
            bool blank = true;
            for (unsigned char c : buf.line(l)) {
                if (std::isspace(c)) { inWord = false; continue; }
                blank = false;
                if (!inWord) { inWord = true; ++wordCount; }
            }
            if (blank) inParagraph = false;                                  // a blank line ends the paragraph
            else if (!inParagraph) { inParagraph = true; ++paragraphCount; }
        }
        m_cachedWords = wordCount;
        m_cachedParagraphs = paragraphCount;
    }
    const int lines = static_cast<int>(buf.lineCount());
    const int words = m_cachedWords;
    const int paragraphs = m_cachedParagraphs;

    const bool dirty = line != m_line || column != m_column || selected != m_selectedChars || cursors != m_cursorCount ||
                       indent != m_indent || encoding != m_encoding || lineEnding != m_lineEnding ||
                       language != m_language || message != m_message ||
                       lines != m_lines || words != m_words || paragraphs != m_paragraphs;
    m_line = line;
    m_column = column;
    m_selectedChars = selected;
    m_cursorCount = cursors;
    m_indent = indent;
    m_encoding = encoding;
    m_lineEnding = lineEnding;
    m_language = language;
    m_message = message;
    m_lines = lines;
    m_words = words;
    m_paragraphs = paragraphs;
    if (dirty) emit changed();
}
