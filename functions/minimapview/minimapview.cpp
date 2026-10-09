#include "minimapview.h"

#include <QAbstractTextDocumentLayout>
#include <QPainter>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextLayout>
#include <QtMath>

MinimapView::MinimapView(QQuickItem *parent)
: QQuickPaintedItem(parent)
{
    m_timer.setSingleShot(true);
    m_timer.setInterval(40);
    connect(&m_timer, &QTimer::timeout, this, &MinimapView::refresh);
}

QTextDocument *MinimapView::textDoc() const
{
    return m_quickDoc ? m_quickDoc->textDocument() : nullptr;
}

void MinimapView::setDocument(QQuickTextDocument *doc)
{
    if (doc == m_quickDoc)
        return;

    if (m_connectedDoc) {
        disconnect(m_connectedDoc, nullptr, this, nullptr);
        if (auto *lay = m_connectedDoc->documentLayout())
            disconnect(lay, nullptr, this, nullptr);
    }

    m_quickDoc = doc;
    m_connectedDoc = textDoc();

    if (m_connectedDoc) {
        connect(m_connectedDoc, &QTextDocument::contentsChanged, this, &MinimapView::schedule);
        if (auto *lay = m_connectedDoc->documentLayout()) {
            connect(lay, &QAbstractTextDocumentLayout::documentSizeChanged, this, &MinimapView::schedule);
            connect(lay, &QAbstractTextDocumentLayout::update, this, &MinimapView::schedule);
        }
    }

    emit documentChanged();
    schedule();
}

void MinimapView::setTextColor(const QColor &c)
{
    if (c == m_textColor)
        return;
    m_textColor = c;
    emit textColorChanged();
    schedule();
}

void MinimapView::setCharWidth(qreal v)
{
    if (qFuzzyCompare(v, m_charWidth))
        return;
    m_charWidth = v;
    emit charWidthChanged();
    schedule();
}

void MinimapView::setScrollProgress(qreal v)
{
    v = qBound<qreal>(0, v, 1);
    if (qFuzzyCompare(v + 1, m_progress + 1))
        return;
    m_progress = v;
    updateOffset();
}

void MinimapView::updateOffset()
{
    const qreal off = qRound(qMax<qreal>(0, m_mapHeight - height()) * m_progress);
    if (!qFuzzyCompare(off + 1, m_offset + 1)) {
        m_offset = off;
        emit mapChanged();
        update();
    }
}

void MinimapView::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        schedule();
}

void MinimapView::schedule()
{
    m_timer.start();
}

qreal MinimapView::lineHeightPx(QTextDocument *doc) const
{
    for (QTextBlock b = doc->begin(); b.isValid(); b = b.next()) {
        const QTextLayout *tl = b.layout();
        if (tl && tl->lineCount() > 0)
            return tl->lineAt(0).height();
    }
    return 18.0;
}

void MinimapView::refresh()
{
    qreal scale = m_scale;
    qreal mapH = 0;
    int pitch = 3;

    if (QTextDocument *doc = textDoc()) {
        const qreal docH = doc->documentLayout()->documentSize().height();
        const qreal lineH = lineHeightPx(doc);
        if (docH > 0 && lineH > 0 && height() > 0) {
            const qreal rows = docH / lineH;                    // visual lines, wraps included
            const qreal pitchF = qMin<qreal>(3.0, height() / rows);   // never taller than the item
            scale = pitchF / lineH;
            mapH = docH * scale;
            pitch = qMax(1, int(pitchF));
        }
    }

    m_pitch = pitch;
    m_scale = scale;
    m_mapHeight = mapH;
    m_offset = 0;                                               // the map never scrolls
    emit mapChanged();
    update();
}

void MinimapView::paint(QPainter *p)
{
    QTextDocument *doc = textDoc();
    if (!doc)
        return;

    auto *layout = doc->documentLayout();
    const qreal s = m_scale;
    const qreal maxX = width() - 2;
    const QRgb defaultRgb = m_textColor.rgba();
    const int rowH = qMax(1, m_pitch - 1);                   // 2px block + 1px gap at pitch 3

    p->setRenderHint(QPainter::Antialiasing, false);

    for (QTextBlock block = doc->begin(); block.isValid(); block = block.next()) {
        if (!block.isVisible())
            continue;
        const QTextLayout *tl = block.layout();
        if (!tl || tl->lineCount() == 0)
            continue;

        const QRectF blockRect = layout->blockBoundingRect(block);
        if (blockRect.height() <= 0)
            continue;

        // Skip blocks that are scrolled out of the map
        const qreal blockTop = blockRect.y() * s - m_offset;
        const qreal blockBottom = blockTop + blockRect.height() * s;
        if (blockBottom < -m_pitch)
            continue;
        if (blockTop > height())
            break;

        const QString text = block.text();

        QList<QRgb> colors(text.size(), defaultRgb);
        const auto ranges = tl->formats();
        for (const QTextLayout::FormatRange &r : ranges) {
            const QBrush fg = r.format.foreground();
            if (fg.style() == Qt::NoBrush)
                continue;
            const QRgb rgb = fg.color().rgba();
            const int end = qMin(r.start + r.length, int(colors.size()));
            for (int i = qMax(0, r.start); i < end; ++i)
                colors[i] = rgb;
        }

        for (int li = 0; li < tl->lineCount(); ++li) {
            const QTextLine line = tl->lineAt(li);
            // Snap every row to a whole pixel so lines never blur together
            const int rowTop = qRound((blockRect.y() + line.y()) * s - m_offset);
            if (rowTop + rowH < 0 || rowTop > height())
                continue;

            int col = 0;
            int i = line.textStart();
            const int end = line.textStart() + line.textLength();

            while (i < end) {
                const QChar ch = text.at(i);
                if (ch == QLatin1Char('\t')) {
                    col += 4 - (col % 4);
                    ++i;
                    continue;
                }
                if (ch.isSpace()) {
                    ++col;
                    ++i;
                    continue;
                }

                const QRgb runRgb = colors[i];
                const int runCol = col;
                while (i < end && !text.at(i).isSpace() && colors[i] == runRgb) {
                    ++col;
                    ++i;
                }

                const int x = qRound(4 + runCol * m_charWidth);
                if (x > maxX)
                    break;

                QColor c = QColor::fromRgba(runRgb);
                c.setAlphaF(0.85);
                const int w = qMax(1, qMin(qRound((col - runCol) * m_charWidth), int(maxX) - x));
                p->fillRect(x, rowTop, w, rowH, c);
            }
        }
    }
}
