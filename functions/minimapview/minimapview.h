#pragma once

#include <QColor>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QQuickTextDocument>
#include <QTextDocument>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class MinimapView : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)
    Q_PROPERTY(qreal charWidth READ charWidth WRITE setCharWidth NOTIFY charWidthChanged)
    // 0..1, how far the editor is scrolled (only matters when the map is taller than the item)
    Q_PROPERTY(qreal scrollProgress READ scrollProgress WRITE setScrollProgress NOTIFY mapChanged)
    // Editor pixels -> minimap pixels, the height of the whole document, and the map's scroll offset
    Q_PROPERTY(qreal mapScale READ mapScale NOTIFY mapChanged)
    Q_PROPERTY(qreal mapHeight READ mapHeight NOTIFY mapChanged)
    Q_PROPERTY(qreal mapOffset READ mapOffset NOTIFY mapChanged)

public:
    explicit MinimapView(QQuickItem *parent = nullptr);

    QQuickTextDocument *document() const { return m_quickDoc; }
    void setDocument(QQuickTextDocument *doc);

    QColor textColor() const { return m_textColor; }
    void setTextColor(const QColor &c);

    qreal charWidth() const { return m_charWidth; }
    void setCharWidth(qreal v);

    qreal scrollProgress() const { return m_progress; }
    void setScrollProgress(qreal v);

    qreal mapScale() const { return m_scale; }
    qreal mapHeight() const { return m_mapHeight; }
    qreal mapOffset() const { return m_offset; }

    void paint(QPainter *painter) override;

signals:
    void documentChanged();
    void textColorChanged();
    void charWidthChanged();
    void mapChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    QTextDocument *textDoc() const;
    qreal lineHeightPx(QTextDocument *doc) const;
    void updateOffset();
    void schedule();
    void refresh();

    QPointer<QQuickTextDocument> m_quickDoc;
    QPointer<QTextDocument> m_connectedDoc;
    QTimer m_timer;
    QColor m_textColor = QColor(0xab, 0xb2, 0xbf);
    qreal m_charWidth = 1.0;
    qreal m_progress = 0;
    qreal m_scale = 0.15;
    qreal m_mapHeight = 0;
    qreal m_offset = 0;
    int m_pitch = 3;
};
