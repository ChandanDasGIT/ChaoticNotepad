#include "multicursor.h"

#include <QSet>
#include <QTextBlock>
#include <algorithm>

MultiCursor::MultiCursor(QObject *parent)
: QObject(parent)
{
}

void MultiCursor::setDocument(QQuickTextDocument *quickDocument)
{
    QTextDocument *doc = quickDocument ? quickDocument->textDocument() : nullptr;
    if (doc == m_doc.data())
        return;

    if (m_doc)
        disconnect(m_doc.data(), &QTextDocument::contentsChange, this, &MultiCursor::onContentsChange);

    m_cursors.clear();
    m_doc = doc;

    if (m_doc)
        connect(m_doc.data(), &QTextDocument::contentsChange, this, &MultiCursor::onContentsChange);

    emitIfChanged();
}

QVariantList MultiCursor::positions() const
{
    QVariantList list;
    list.reserve(m_cursors.size());
    for (const QTextCursor &c : m_cursors)
        list.append(c.position());
    return list;
}

void MultiCursor::addCursor(int position)
{
    if (!m_doc)
        return;

    QTextCursor c(m_doc.data());
    c.setPosition(qBound(0, position, qMax(0, m_doc->characterCount() - 1)));
    m_cursors.append(c);
    prune(-1);
    emitIfChanged();
}

void MultiCursor::clear()
{
    m_cursors.clear();
    emitIfChanged();
}

void MultiCursor::mergeWith(int primaryPosition)
{
    if (m_cursors.isEmpty())
        return;
    prune(primaryPosition);
    emitIfChanged();
}

void MultiCursor::move(const QString &direction, bool byWord)
{
    if (m_cursors.isEmpty())
        return;

    QTextCursor::MoveOperation op;
    if (direction == QLatin1String("left"))
        op = byWord ? QTextCursor::PreviousWord : QTextCursor::Left;
    else if (direction == QLatin1String("right"))
        op = byWord ? QTextCursor::NextWord : QTextCursor::Right;
    else if (direction == QLatin1String("up"))
        op = QTextCursor::Up;
    else if (direction == QLatin1String("down"))
        op = QTextCursor::Down;
    else if (direction == QLatin1String("home"))
        op = QTextCursor::StartOfBlock;
    else if (direction == QLatin1String("end"))
        op = QTextCursor::EndOfBlock;
    else
        return;

    for (QTextCursor &c : m_cursors)
        c.movePosition(op);

    prune(-1);
    emitIfChanged();
}

int MultiCursor::insertText(const QString &text, int primaryPosition)
{
    return apply(primaryPosition, [&text](QTextCursor &c) { c.insertText(text); });
}

int MultiCursor::insertNewline(int primaryPosition)
{
    // New line keeps the indentation of the line the caret is on
    return apply(primaryPosition, [](QTextCursor &c) {
        const QString block = c.block().text();
        const int column = c.positionInBlock();
        int n = 0;
        while (n < column && n < block.size() && block.at(n).isSpace())
            ++n;
        c.insertText(QStringLiteral("\n") + block.left(n));
    });
}

int MultiCursor::deleteBackward(int primaryPosition)
{
    return apply(primaryPosition, [](QTextCursor &c) { c.deletePreviousChar(); });
}

int MultiCursor::deleteForward(int primaryPosition)
{
    return apply(primaryPosition, [](QTextCursor &c) { c.deleteChar(); });
}

void MultiCursor::onContentsChange(int position, int removed, int added)
{
    if (m_applying || m_cursors.isEmpty() || !m_doc)
        return;

    // The whole text was replaced (tab switch, fold/unfold, reload): extra carets are meaningless now
    if (position == 0 && removed > 0 && added >= m_doc->characterCount() - 1) {
        clear();
        return;
    }

    // Normal edit elsewhere: the carets moved along with the text
    prune(-1);
    emitIfChanged();
}

int MultiCursor::apply(int primaryPosition, const std::function<void(QTextCursor &)> &op)
{
    if (!m_doc)
        return primaryPosition;

    QTextCursor primary = makePrimary(primaryPosition);

    m_applying = true;
    primary.beginEditBlock();   // one undo step for all carets
    for (QTextCursor &c : m_cursors)
        op(c);
    op(primary);
    primary.endEditBlock();
    m_applying = false;

    prune(primary.position());
    emitIfChanged();
    return primary.position();
}

QTextCursor MultiCursor::makePrimary(int position)
{
    QTextCursor primary(m_doc.data());
    primary.setPosition(qBound(0, position, qMax(0, m_doc->characterCount() - 1)));
    prune(primary.position());
    return primary;
}

// Removes duplicate carets (and any caret sitting on the primary one), keeps them sorted
void MultiCursor::prune(int primaryPosition)
{
    QVector<QTextCursor> unique;
    QSet<int> seen;
    if (primaryPosition >= 0)
        seen.insert(primaryPosition);

    for (const QTextCursor &c : std::as_const(m_cursors)) {
        if (c.isNull())
            continue;
        const int p = c.position();
        if (seen.contains(p))
            continue;
        seen.insert(p);
        unique.append(c);
    }

    std::sort(unique.begin(), unique.end(), [](const QTextCursor &a, const QTextCursor &b) {
        return a.position() < b.position();
    });
    m_cursors = unique;
}

void MultiCursor::emitIfChanged()
{
    const QVariantList now = positions();
    if (now != m_lastPositions) {
        m_lastPositions = now;
        emit positionsChanged();
    }
}
