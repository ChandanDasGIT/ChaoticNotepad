#include "stickyscroll.h"
#include <QTextBlock>
#include <QVariantMap>

StickyScroll::StickyScroll(QObject *parent)
: QObject(parent)
{
}

void StickyScroll::setDocument(QQuickTextDocument *doc)
{
    if (m_doc)
        disconnect(m_doc.data(), nullptr, this, nullptr);

    m_doc = doc ? doc->textDocument() : nullptr;

    if (m_doc) {
        connect(m_doc.data(), &QTextDocument::contentsChange, this, &StickyScroll::onContentsChange);
        m_dirty = true;
    }
}

void StickyScroll::onContentsChange()
{
    m_dirty = true; // Only recalculate scopes when text actually changes, not on scroll
}

void StickyScroll::recalculateScopes()
{
    if (!m_doc) return;
    m_scopeEnds.clear();
    m_scopeEnds.fill(-1, m_doc->blockCount());

    struct Open { QChar close; int line; };
    QList<Open> stack;
    bool inBlockComment = false;
    int line = 0;

    for (QTextBlock b = m_doc->begin(); b.isValid(); b = b.next(), ++line) {
        const QString t = b.text();
        const int n = t.size();
        int i = 0;
        while (i < n) {
            const QChar c = t.at(i);

            if (inBlockComment) {
                if (c == '*' && i + 1 < n && t.at(i + 1) == '/') {
                    inBlockComment = false;
                    i += 2;
                } else {
                    ++i;
                }
                continue;
            }
            if (c == '/' && i + 1 < n) {
                if (t.at(i + 1) == '/')
                    break;
                if (t.at(i + 1) == '*') {
                    inBlockComment = true;
                    i += 2;
                    continue;
                }
            }
            if (c == '"' || c == '\'') {
                int j = i + 1;
                while (j < n && t.at(j) != c) {
                    if (t.at(j) == '\\')
                        ++j;
                    ++j;
                }
                i = j + 1;
                continue;
            }

            if (c == '{' || c == '(' || c == '[') {
                const QChar closeCh = (c == '{') ? QChar('}') : (c == '(') ? QChar(')') : QChar(']');
                stack.append(Open{closeCh, line});
            } else if (c == '}' || c == ')' || c == ']') {
                for (int k = stack.size() - 1; k >= 0; --k) {
                    if (stack.at(k).close == c) {
                        const int open = stack.at(k).line;
                        if (line > open && line > m_scopeEnds[open])
                            m_scopeEnds[open] = line;
                        stack.resize(k);
                        break;
                    }
                }
            }
            ++i;
        }
    }
    m_dirty = false;
}
/////////////
QVariantList StickyScroll::getStickyLinesForPosition(int pos)
{
    QVariantList result;
    if (!m_doc) return result;
    if (m_dirty) recalculateScopes();

    QTextBlock topBlock = m_doc->findBlock(pos);
    if (!topBlock.isValid()) return result;

    const int topVisibleLine = topBlock.blockNumber();
    QList<int> activeHeaders;

    for (int i = 0; i < topVisibleLine && i < m_scopeEnds.size(); ++i) {
        int closeLine = m_scopeEnds.at(i);
        if (closeLine > topVisibleLine) {
            activeHeaders.append(i);
        }
    }

    if (activeHeaders.size() > 5) {
        activeHeaders = activeHeaders.mid(activeHeaders.size() - 5);
    }

    if (activeHeaders.isEmpty())
        return result;

    // Single clean loop over active headers
    for (int lineNum : activeHeaders) {
        QTextBlock b = m_doc->findBlockByNumber(lineNum);
        QString rawText = b.text();
        int actualLineNum = lineNum + 1;
        int actualPosition = b.position(); // Track the character index for clicking

        // Handle dangling brackets
        if (rawText.trimmed() == "{" || rawText.trimmed() == "[" || rawText.trimmed() == "(") {
            QTextBlock prev = b.previous();
            while (prev.isValid() && prev.text().trimmed().isEmpty()) {
                prev = prev.previous();
            }
            if (prev.isValid()) {
                rawText = prev.text();
                actualLineNum = prev.blockNumber() + 1;
                actualPosition = prev.position(); // Grab the dangling header's position
            }
        }

        while (rawText.endsWith(' ') || rawText.endsWith('\t')) {
            rawText.chop(1);
        }

        // Package the line number, text, and position together
        QVariantMap lineData;
        lineData["lineNum"] = actualLineNum;
        lineData["text"] = rawText;
        lineData["position"] = actualPosition;
        result.append(lineData);
    }

    return result;
}
