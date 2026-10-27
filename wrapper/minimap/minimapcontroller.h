#pragma once
#include <QColor>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include "textengine/minimap/minimap.h"

class QQmlEngine;
class QJSEngine;

// What Minimap.qml talks to (MinimapController in QML). It works out the minimap with the engine, like the
// terminal program does; MinimapPicture (minimappicture.h) draws the cells.
class MinimapController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool shown READ shown NOTIFY changed)
    Q_PROPERTY(int pictureColumns READ pictureColumns NOTIFY changed)
    Q_PROPERTY(int pictureRows READ pictureRows NOTIFY changed)
    Q_PROPERTY(int viewportTop READ viewportTop NOTIFY changed)
    Q_PROPERTY(int viewportRows READ viewportRows NOTIFY changed)
    Q_PROPERTY(QVariantList marks READ marks NOTIFY changed)

public:

    static MinimapController* instance();
    static MinimapController* create(QQmlEngine*, QJSEngine*);

    bool shown() const { return m_shown; }
    int pictureColumns() const { return m_columns; }
    int pictureRows() const { return m_rows; }
    int viewportTop() const { return m_vTop; }
    int viewportRows() const { return m_vRows; }
    QVariantList marks() const { return m_marks; }

    // For MinimapPicture
    const Minimap& map() const { return m_map; }
    const std::vector<QRgb>& palette() const { return m_palette; }

    Q_INVOKABLE void setSize(int columns, int rows);           // how many minimap pixels fit
    Q_INVOKABLE void setPalette(const QVariantList& colors);   // the colour of each syntax token number
    Q_INVOKABLE void pressed(int row);
    Q_INVOKABLE void dragged(int row);
    Q_INVOKABLE void released();

signals:
    void changed();

private:
    // Private on purpose: there is exactly one, made by instance(). QML gets it through create().
    // (With a public constructor Qt may build a second one, and then QML and the wrappers talk to different objects.)
    explicit MinimapController(QObject* parent = nullptr);

    void schedule();       // several changes in a row are worked out once
    void update();
    void scrollToLine(size_t line);

    Minimap m_map;
    MinimapConfig m_config;

    int m_sizeColumns = 0;
    int m_sizeRows = 0;
    std::vector<QRgb> m_palette;

    bool m_shown = true;
    bool m_scheduled = false;
    int m_columns = 0;
    int m_rows = 0;
    int m_vTop = 0;
    int m_vRows = 0;
    size_t m_visibleLines = 1;
    size_t m_grab = 0;
    QVariantList m_marks;

    int m_lastTabId = -1;
    unsigned long long m_lastRevision = 0;
    int m_paletteVersion = 0;
    int m_drawnPalette = -1;
};
