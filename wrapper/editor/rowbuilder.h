#pragma once
#include <cstddef>
#include <string>
#include <vector>
#include "textengine/tabs/tabmanager.h"
#include "textengine/stickyscroll/stickyscroll.h"
#include "textengine/wordwrap/wordwrap.h"

// Turns what the engine knows about the current tab into what the editor draws, row by row.
// It has NO Qt in it: the Qt classes of the wrapper only copy its results into Qt types.
// All horizontal positions are in CELLS (one cell = one character of the monospace font), counted from
// the start of the row. Tabs are already turned into spaces, so a tab takes the cells up to the next
// multiple of kTabWidth.

struct RowSpan {                 // a piece of text that has one colour and one style
    int start = 0;               // first cell
    std::string text;            // UTF-8, tabs already replaced by spaces
    int kind = 0;                // the engine's Token number (0 = plain text)
    bool bold = false;
    bool italic = false;
    bool underline = false;
};

struct CellRange {
    int from = 0;                // first cell
    int to = 0;                  // one past the last cell
};

struct RowCursor {
    int cell = 0;
    bool main = false;
};

struct RowMatch {                // a find match
    int from = 0;
    int to = 0;
    bool current = false;
};

struct RowData {
    int lineNumber = 0;          // 1-based; 0 for the continuation of a wrapped line
    int length = 0;              // the row's text length in cells
    std::vector<RowSpan> spans;
    std::vector<CellRange> selection;   // selected cells; to == length + 1 means the line break is selected too
    std::vector<RowCursor> cursors;
    std::vector<RowMatch> matches;
    std::vector<int> brackets;   // cells of brackets to highlight
    int fold = 0;                // gutter arrow, on the first row of a line: 0 none, 1 can be folded, 2 folded
    bool foldPill = false;       // draw the "..." after the text (the last row of a folded header)
    bool foldSelected = false;   // that pill is part of the selection
    std::string foldTail;        // the text after the "...", e.g. "}"
    int change = 0;              // 0 untouched, 1 unsaved, 2 saved
    bool isCursorLine = false;
};

struct StickyRow {               // one pinned header line
    int row = 0;                 // the visible row to jump to when it is clicked
    int lineNumber = 0;          // 1-based
    int length = 0;              // in cells
    std::vector<RowSpan> spans;
};

class RowBuilder {
public:
    static constexpr size_t kTabWidth = 4;

    // Works out the visible rows of this tab for a window `columns` cells wide. Call it whenever the text,
    // the folds, the cursors, the find matches or the width changed (TextView::stateRevision() tells).
    // Update tab.syntax and tab.gutter before it, as the terminal program does for every frame.
    void update(const EditorTab& tab, size_t columns);

    size_t rowCount() const { return m_rows.size(); }
    int gutterDigits() const { return m_digits; }
    const std::vector<size_t>& rowLines() const { return m_rowLines; }   // the document line of every visible row

    RowData row(const EditorTab& tab, size_t index) const;

    // ---- cursor and mouse ----
    size_t mainCursorRow() const { return m_mainRow; }
    size_t rowOf(Position p) const;                                      // the visible row that holds p
    Position positionAt(const EditorTab& tab, size_t row, size_t cell) const;   // mouse: row and cell -> text position
    size_t firstRowOfLine(size_t line) const;                            // first visible row of a line (or the next visible one)

    // ---- sticky scroll ----
    // The pinned header lines when `firstRow` is the first row on screen. At most `maxRows` of them.
    std::vector<StickyRow> sticky(const EditorTab& tab, const StickyScroll& scroll, size_t firstRow, size_t maxRows) const;

private:
    struct Placed { size_t row; int cell; bool main; };

    std::vector<RowSpan> spansFor(const EditorTab& tab, size_t line, size_t start, size_t end, size_t& cells) const;

    std::vector<WordWrap::VisualRow> m_rows;
    std::vector<size_t> m_rowLines;
    std::vector<Placed> m_cursors;              // sorted by row
    std::vector<size_t> m_cursorLines;          // sorted lines that hold a cursor
    std::vector<Position> m_brackets;
    size_t m_mainRow = 0;
    int m_digits = 1;
};
