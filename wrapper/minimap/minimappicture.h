#pragma once
#include <QQuickPaintedItem>
#include <QtQml/qqmlregistration.h>

// Draws the minimap cells, one small square for each, the way the terminal program draws its dots:
// a cell that is nearly empty is skipped, the others take the colour of their syntax token.
// Used by Minimap.qml as   MinimapPicture { pixel: 2 }
class MinimapPicture : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int pixel READ pixel WRITE setPixel NOTIFY pixelChanged)   // screen pixels per minimap pixel

public:
    explicit MinimapPicture(QQuickItem* parent = nullptr);

    int pixel() const { return m_pixel; }
    void setPixel(int pixel);

    void paint(QPainter* painter) override;

signals:
    void pixelChanged();

private:
    int m_pixel = 2;
};
