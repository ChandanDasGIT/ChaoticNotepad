#include "wrapper/minimap/minimapcontroller.h"
#include <algorithm>
#include <QJSEngine>
#include <QTimer>
#include <QVariantMap>
#include "wrapper/editor/editorcontroller.h"

namespace {
const size_t kMinimapChars = 120;   // how many characters of a line the picture covers
}

MinimapController* MinimapController::instance() {
    static MinimapController* inst = new MinimapController();
    return inst;
}

MinimapController* MinimapController::create(QQmlEngine*, QJSEngine*) {
    MinimapController* inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);
    return inst;
}

MinimapController::MinimapController(QObject* parent) : QObject(parent) {
    static int count = 0;
    if (++count > 1) qWarning("MinimapController was created twice: QML and the wrappers are using different objects"); 
    m_palette.assign(15, qRgb(200, 200, 200));
    EditorController* ed = EditorController::instance();
    connect(ed, &EditorController::rowsRebuilt, this, &MinimapController::schedule);
    connect(ed, &EditorController::viewChanged, this, &MinimapController::schedule);
    connect(ed, &EditorController::documentChanged, this, &MinimapController::schedule);
}

void MinimapController::setSize(int columns, int rows) {
    columns = std::max(columns, 1);
    rows = std::max(rows, 1);
    if (columns == m_sizeColumns && rows == m_sizeRows) return;
    m_sizeColumns = columns;
    m_sizeRows = rows;
    schedule();
}

void MinimapController::setPalette(const QVariantList& colors) {
    std::vector<QRgb> palette;
    for (const QVariant& v : colors) palette.push_back(v.value<QColor>().rgb());
    if (palette.empty() || palette == m_palette) return;
    m_palette = palette;
    ++m_paletteVersion;
    schedule();
}

void MinimapController::schedule() {
    if (m_scheduled) return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this] { m_scheduled = false; update(); });
}

void MinimapController::update() {
    EditorController* ed = EditorController::instance();
    const bool shown = ed->inputState().minimapOn;
    bool dirty = shown != m_shown;
    m_shown = shown;
    if (!shown || m_sizeColumns <= 0) {
        if (dirty) emit changed();
        return;
    }

    EditorTab& tab = ed->tab();
    const TextView& view = tab.view;

    // the picture, built the way the terminal program does it
    MinimapConfig cfg;
    cfg.width = static_cast<size_t>(m_sizeColumns);
    cfg.height = static_cast<size_t>(m_sizeRows);
    cfg.charsPerPixel = (kMinimapChars + cfg.width - 1) / cfg.width;
    cfg.tabWidth = 4;
    if (cfg.width != m_config.width || cfg.height != m_config.height ||
        cfg.charsPerPixel != m_config.charsPerPixel || cfg.tabWidth != m_config.tabWidth) {
        m_config = cfg;
        m_map.setConfig(cfg);
        m_map.invalidate();
    }
    if (tab.id != m_lastTabId) m_map.invalidate();                  // another tab: the picture is of the wrong file
    const SyntaxHighlighter* syntax = &tab.syntax;
    m_map.rebuild(view.buffer(), [syntax](size_t l, size_t c) { return static_cast<unsigned char>(syntax->tokenAt(l, c)); });

    // the marks, then the part that is on screen
    m_map.setCursorMarks(view.cursors());
    m_map.setFindMarks(view.findMatches(), view.findCurrent());
    const GutterStyle& gutter = tab.gutter;
    m_map.setChangeMarks([&gutter](size_t l) { return gutter.unsavedAt(l); },
                         [&gutter](size_t l) { return gutter.savedChangeAt(l); });

    const std::vector<size_t>& rowLines = ed->builder().rowLines();
    if (!rowLines.empty()) {
        const size_t first = std::min(ed->firstRow(), rowLines.size() - 1);
        const size_t last = std::min(first + ed->viewRows(), rowLines.size()) - 1;
        m_visibleLines = rowLines[last] - rowLines[first] + 1;
        m_map.setViewport(rowLines[first], m_visibleLines);
    }

    // anything that changes the picture makes the item draw it again
    const unsigned long long revision = view.stateRevision();
    if (tab.id != m_lastTabId || revision != m_lastRevision || m_paletteVersion != m_drawnPalette) dirty = true;
    m_lastTabId = tab.id;
    m_lastRevision = revision;
    m_drawnPalette = m_paletteVersion;

    const int columns = static_cast<int>(m_map.width());
    const int rows = static_cast<int>(m_map.rows());
    const int vTop = static_cast<int>(m_map.viewportTopRow());
    const int vRows = static_cast<int>(m_map.viewportRows());
    if (columns != m_columns || rows != m_rows || vTop != m_vTop || vRows != m_vRows) dirty = true;
    m_columns = columns;
    m_rows = rows;
    m_vTop = vTop;
    m_vRows = vRows;

    QVariantList marks;
    for (size_t r = 0; r < m_map.rows(); ++r) {
        const unsigned char bits = m_map.marks(r);
        if (bits == 0) continue;
        const int edit = bits & MarkChangedUnsaved ? 1 : bits & MarkChangedSaved ? 2 : 0;
        const int find = bits & MarkFindCurrent ? 4 : bits & MarkFind ? 3 : bits & MarkCursor ? 2 : bits & MarkSelection ? 1 : 0;
        if (edit == 0 && find == 0) continue;
        QVariantMap m;
        m["row"] = static_cast<int>(r);
        m["edit"] = edit;
        m["find"] = find;
        marks.append(m);
    }
    if (marks != m_marks) {
        m_marks = marks;
        dirty = true;
    }

    if (dirty) emit changed();
}

// ------------------------------------------------------------------ mouse

// Scrolls the text so that this document line is the first one on screen.
void MinimapController::scrollToLine(size_t line) {
    EditorController* ed = EditorController::instance();
    const std::vector<size_t>& rowLines = ed->builder().rowLines();
    if (rowLines.empty()) return;
    size_t i = 0;
    while (i + 1 < rowLines.size() && rowLines[i] < line) ++i;       // document line -> screen row
    ed->scrollToRow(i);
}

void MinimapController::pressed(int row) {
    if (m_map.rows() == 0) return;
    const size_t px = static_cast<size_t>(std::clamp(row, 0, static_cast<int>(m_map.rows()) - 1));
    size_t target;
    if (!m_map.rowInViewport(px)) {                                   // a click outside the rectangle: jump there
        target = m_map.scrollTopForRow(px, m_visibleLines);
        m_grab = m_map.viewportRows() / 2;
    } else {                                                          // grab the rectangle
        m_grab = px - m_map.viewportTopRow();
        target = m_map.scrollTopForDrag(px, m_grab, m_visibleLines);
    }
    scrollToLine(target);
}

void MinimapController::dragged(int row) {
    if (m_map.rows() == 0) return;
    const size_t px = static_cast<size_t>(std::clamp(row, 0, static_cast<int>(m_map.rows()) - 1));
    scrollToLine(m_map.scrollTopForDrag(px, m_grab, m_visibleLines));
}

void MinimapController::released() {
    m_grab = 0;
}
