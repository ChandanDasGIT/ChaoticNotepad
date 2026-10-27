#include "rowbuilder.h"
#include <algorithm>

namespace {

// ---- characters and cells (the same rules as the terminal program) ----

char32_t decodeAt(const std::string& s, size_t i, size_t& len) {
    unsigned char c = static_cast<unsigned char>(s[i]);
    size_t n = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1;
    if (i + n > s.size()) n = 1;
    char32_t cp = n == 1 ? c : n == 2 ? (c & 0x1F) : n == 3 ? (c & 0x0F) : (c & 0x07);
    for (size_t k = 1; k < n; ++k) cp = (cp << 6) | (static_cast<unsigned char>(s[i + k]) & 0x3F);
    len = n;
    return cp;
}

int cellWidthOf(char32_t cp) {
    if (cp == 0) return 0;
    if ((cp >= 0x0300 && cp <= 0x036F) || (cp >= 0x200B && cp <= 0x200F) || (cp >= 0xFE00 && cp <= 0xFE0F)) return 0;
    if ((cp >= 0x1100 && cp <= 0x115F) || (cp >= 0x2E80 && cp <= 0xA4CF) || (cp >= 0xAC00 && cp <= 0xD7A3) ||
        (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFE30 && cp <= 0xFE6F) || (cp >= 0xFF00 && cp <= 0xFF60) ||
        (cp >= 0xFFE0 && cp <= 0xFFE6) || (cp >= 0x1F300 && cp <= 0x1F64F) || (cp >= 0x1F900 && cp <= 0x1F9FF) ||
        (cp >= 0x20000 && cp <= 0x3FFFD))
        return 2;
    return 1;
}

// cells a character takes when it starts at cell `col` of its row (a tab reaches the next tab stop)
size_t charCells(char32_t cp, size_t col) {
    return cp == U'\t' ? RowBuilder::kTabWidth - col % RowBuilder::kTabWidth : static_cast<size_t>(cellWidthOf(cp));
}

// cells taken by the bytes [from, to) of s, when `from` is at cell 0 (the start of a row)
size_t cellsBetween(const std::string& s, size_t from, size_t to) {
    size_t cells = 0;
    to = std::min(to, s.size());
    while (from < to) {
        size_t len = 1;
        char32_t cp = decodeAt(s, from, len);
        cells += charCells(cp, cells);
        from += len;
    }
    return cells;
}

// The byte (between start and end) that sits under cell `cell`. A cell in the right half of a wide
// character belongs to the next character. Past the end gives `end`.
size_t byteAtCell(const std::string& s, size_t start, size_t end, size_t cell) {
    size_t b = start, cells = 0;
    end = std::min(end, s.size());
    while (b < end) {
        size_t len = 1;
        char32_t cp = decodeAt(s, b, len);
        size_t w = charCells(cp, cells);
        if (cell < cells + std::max<size_t>(w, 1)) return (w >= 2 && cell > cells + (w - 1) / 2) ? b + len : b;
        cells += w;
        b += len;
    }
    return end;
}

bool onlySpaces(const std::string& s) { return s.find_first_not_of(' ') == std::string::npos; }

// The part of the range [s, e) that lies on row r, as bytes of the line. `lineBreak` tells that the range
// goes on past the end of the line. False when the range does not touch the row.
bool intersect(Position s, Position e, const WordWrap::VisualRow& r, size_t& fromByte, size_t& toByte, bool& lineBreak) {
    if (e.line < r.line) return false;
    if (e.line == r.line && e.col <= r.start) return false;               // ends before the row begins
    if (s.line > r.line) return false;
    if (s.line == r.line && s.col > r.end) return false;
    fromByte = (s.line < r.line || s.col <= r.start) ? r.start : s.col;
    toByte = e.line > r.line ? r.end : std::min(e.col, r.end);
    lineBreak = r.last && e.line > r.line;
    if (fromByte > toByte) return false;
    if (fromByte == toByte && !lineBreak) return false;
    return true;
}

}  // namespace

// ---------------------------------------------------------------- the layout

void RowBuilder::update(const EditorTab& tab, size_t columns) {
    const TextView& v = tab.view;
    const TextBuffer& b = v.buffer();

    m_rows = v.folding().visibleRows(WordWrap::layout(b, std::max<size_t>(columns, 1), kTabWidth));
    m_rowLines.clear();
    m_rowLines.reserve(m_rows.size());
    for (const auto& r : m_rows) m_rowLines.push_back(r.line);

    size_t digits = 1;
    for (size_t n = b.lineCount(); n >= 10; n /= 10) ++digits;
    m_digits = static_cast<int>(digits);

    // cursors: the row and the cell of each
    m_cursors.clear();
    m_cursorLines.clear();
    const std::vector<Cursor>& cs = v.cursors();
    size_t mainIdx = v.mainCursorIndex();
    m_mainRow = 0;
    for (size_t i = 0; i < cs.size(); ++i) {
        size_t r = 0, byteCol = 0;
        WordWrap::toScreen(m_rows, cs[i].pos, r, byteCol);
        int cell = 0;
        if (r < m_rows.size())
            cell = static_cast<int>(cellsBetween(b.line(m_rows[r].line), m_rows[r].start, m_rows[r].start + byteCol));
        m_cursors.push_back({r, cell, i == mainIdx});
        m_cursorLines.push_back(cs[i].pos.line);
        if (i == mainIdx) m_mainRow = r;
    }
    std::stable_sort(m_cursors.begin(), m_cursors.end(), [](const Placed& a, const Placed& c) { return a.row < c.row; });
    std::sort(m_cursorLines.begin(), m_cursorLines.end());

    m_brackets.clear();
    for (const BracketPair& bp : v.bracketMatches()) {
        m_brackets.push_back(bp.at);
        m_brackets.push_back(bp.partner);
    }
}

// ---------------------------------------------------------------- one row

std::vector<RowSpan> RowBuilder::spansFor(const EditorTab& tab, size_t line, size_t start, size_t end, size_t& cells) const {
    const std::string& s = tab.view.buffer().line(line);
    std::vector<RowSpan> spans;
    RowSpan cur;
    bool open = false;

    auto flush = [&]() {
        if (open && (!onlySpaces(cur.text) || cur.underline)) spans.push_back(cur);
        open = false;
    };

    size_t cell = 0;
    size_t c = start;
    while (c < end && c < s.size() && Utf8::isContinuation(s[c])) ++c;       // a character that the wrap cut belongs to the row above
    while (c < end && c < s.size()) {
        size_t nxt = Utf8::nextBoundary(s, c);
        size_t len = 1;
        char32_t cp = decodeAt(s, c, len);
        size_t w = charCells(cp, cell);
        int kind = static_cast<int>(tab.syntax.tokenAt(line, c));
        CharStyle st = tab.view.styleAt(line, c);

        bool same = open && cur.kind == kind && cur.bold == st.bold && cur.italic == st.italic && cur.underline == st.underline;
        if (!same && !(open && w == 0)) {                                    // a combining mark stays with its letter
            flush();
            cur = RowSpan();
            cur.start = static_cast<int>(cell);
            cur.kind = kind;
            cur.bold = st.bold;
            cur.italic = st.italic;
            cur.underline = st.underline;
            open = true;
        }
        if (cp == U'\t') cur.text.append(w, ' ');
        else cur.text.append(s, c, nxt - c);
        cell += w;
        c = nxt;
    }
    flush();
    cells = cell;
    return spans;
}

RowData RowBuilder::row(const EditorTab& tab, size_t index) const {
    RowData d;
    if (index >= m_rows.size()) return d;
    const WordWrap::VisualRow& r = m_rows[index];
    const TextView& v = tab.view;
    const std::string& line = v.buffer().line(r.line);

    size_t cells = 0;
    d.spans = spansFor(tab, r.line, r.start, r.end, cells);
    d.length = static_cast<int>(cells);
    d.lineNumber = r.start == 0 ? static_cast<int>(r.line) + 1 : 0;
    d.change = static_cast<int>(tab.gutter.markAt(r.line));
    d.isCursorLine = std::binary_search(m_cursorLines.begin(), m_cursorLines.end(), r.line);

    // ---- folding ----
    FoldMark mark = v.folding().markAt(r.line);
    if (r.start == 0) d.fold = mark == FoldMark::Folded ? 2 : mark == FoldMark::Expanded ? 1 : 0;
    if (r.last && v.folding().isFolded(r.line)) {
        d.foldPill = true;
        d.foldTail = v.folding().placeholder(r.line);
        d.foldSelected = v.isFoldSelected(r.line);
    }

    // ---- selections ----
    for (const Cursor& c : v.cursors()) {
        if (!c.hasSelection()) continue;
        size_t fb = 0, tb = 0;
        bool brk = false;
        if (!intersect(c.start(), c.end(), r, fb, tb, brk)) continue;
        CellRange cr;
        cr.from = static_cast<int>(cellsBetween(line, r.start, fb));
        cr.to = static_cast<int>(cellsBetween(line, r.start, tb));
        if (brk) cr.to = d.length + 1;
        if (cr.to > cr.from) d.selection.push_back(cr);
    }

    // ---- find matches ----
    const std::vector<Range>& ms = v.findMatches();
    int current = v.findCurrent();
    Position rowStart{r.line, r.start};
    auto it = std::lower_bound(ms.begin(), ms.end(), rowStart, [](const Range& m, Position p) { return !(p < m.to); });
    for (; it != ms.end() && it->from.line <= r.line; ++it) {
        size_t fb = 0, tb = 0;
        bool brk = false;
        if (!intersect(it->from, it->to, r, fb, tb, brk)) continue;
        RowMatch m;
        m.from = static_cast<int>(cellsBetween(line, r.start, fb));
        m.to = static_cast<int>(cellsBetween(line, r.start, tb));
        m.current = static_cast<int>(it - ms.begin()) == current;
        if (m.to > m.from) d.matches.push_back(m);
    }

    // ---- brackets ----
    for (const Position& p : m_brackets)
        if (p.line == r.line && p.col >= r.start && p.col < r.end)
            d.brackets.push_back(static_cast<int>(cellsBetween(line, r.start, p.col)));

    // ---- cursors ----
    auto first = std::lower_bound(m_cursors.begin(), m_cursors.end(), index, [](const Placed& p, size_t row) { return p.row < row; });
    for (; first != m_cursors.end() && first->row == index; ++first) {
        RowCursor rc;
        rc.cell = first->cell;
        rc.main = first->main;
        d.cursors.push_back(rc);
    }
    return d;
}

// ---------------------------------------------------------------- cursor and mouse

size_t RowBuilder::rowOf(Position p) const {
    size_t r = 0, byteCol = 0;
    WordWrap::toScreen(m_rows, p, r, byteCol);
    return r;
}

Position RowBuilder::positionAt(const EditorTab& tab, size_t row, size_t cell) const {
    if (m_rows.empty()) return Position{0, 0};
    row = std::min(row, m_rows.size() - 1);
    const WordWrap::VisualRow& r = m_rows[row];
    size_t b = byteAtCell(tab.view.buffer().line(r.line), r.start, r.end, cell);
    return WordWrap::toPosition(m_rows, row, b - r.start);
}

size_t RowBuilder::firstRowOfLine(size_t line) const {
    auto it = std::lower_bound(m_rowLines.begin(), m_rowLines.end(), line);
    return static_cast<size_t>(it - m_rowLines.begin());
}

// ---------------------------------------------------------------- sticky scroll

std::vector<StickyRow> RowBuilder::sticky(const EditorTab& tab, const StickyScroll& scroll, size_t firstRow, size_t maxRows) const {
    std::vector<StickyRow> out;
    if (firstRow >= m_rows.size() || maxRows == 0) return out;

    std::vector<size_t> lines;
    for (size_t i = firstRow; i < m_rows.size() && lines.size() <= scroll.maxLines(); ++i) lines.push_back(m_rows[i].line);

    std::vector<StickyLine> pins = scroll.compute(lines);
    if (pins.size() > maxRows) pins.resize(maxRows);

    for (const StickyLine& p : pins) {
        StickyRow s;
        s.row = static_cast<int>(firstRowOfLine(p.line));
        s.lineNumber = static_cast<int>(p.line) + 1;
        size_t cells = 0;
        s.spans = spansFor(tab, p.line, 0, tab.view.buffer().line(p.line).size(), cells);
        s.length = static_cast<int>(cells);
        out.push_back(std::move(s));
    }
    return out;
}
