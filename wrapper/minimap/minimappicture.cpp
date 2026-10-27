#include "wrapper/minimap/minimappicture.h"
#include <QColor>
#include <QPainter>
#include <algorithm>
#include "wrapper/minimap/minimapcontroller.h"

MinimapPicture::MinimapPicture(QQuickItem* parent) : QQuickPaintedItem(parent) {
    // draw again whenever the minimap changed
    connect(MinimapController::instance(), &MinimapController::changed, this, [this] { update(); });
}

void MinimapPicture::setPixel(int pixel) {
    pixel = std::max(pixel, 1);
    if (pixel == m_pixel) return;
    m_pixel = pixel;
    emit pixelChanged();
    update();
}

void MinimapPicture::paint(QPainter* painter) {
    const MinimapController* controller = MinimapController::instance();
    const Minimap& map = controller->map();
    const std::vector<QRgb>& palette = controller->palette();
    if (palette.empty()) return;

    if (map.rows() == 0) return;
    const double rowHeight = height() / static_cast<double>(map.rows());     // the item's height is shared out over the rows
    for (size_t y = 0; y < map.rows(); ++y) {
        const int top = static_cast<int>(y * rowHeight);
        const int bottom = static_cast<int>((y + 1) * rowHeight);            // whole pixels, so there are no seams between rows
        const int h = std::max(1, bottom - top);
        for (size_t x = 0; x < map.width(); ++x) {
            const MinimapCell c = map.cell(y, x);
            if (c.density <= 40) continue;                                   // (the terminal skips cells under 60)
            const QRgb base = palette[std::min<size_t>(c.kind, palette.size() - 1)];
            const int alpha = std::min(255, 90 + c.density);                 // thin text is fainter than dense text
            painter->fillRect(static_cast<int>(x) * m_pixel, top, m_pixel, h,
                              QColor(qRed(base), qGreen(base), qBlue(base), alpha));
        }
    }
}
