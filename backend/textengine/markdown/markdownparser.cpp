#include "markdownparser.h"
#include <algorithm>
#include <cctype>
#include <sstream>

// ---------------------------------------------------------------------------
// Themes — colours are from the same palette used in minimapcontroller.cpp
// ---------------------------------------------------------------------------

MarkdownTheme MarkdownParser::darkTheme() {
    MarkdownTheme t;
    t.bodyBg       = "#282c34";   // One Dark background
    t.bodyFg       = "#abb2bf";   // None token colour
    t.headingFg    = "#61afef";   // Type/Function colour
    t.codeBg       = "#2c313a";   // slightly lighter bg
    t.codeFg       = "#98c379";   // String colour (green)
    t.blockquoteBg = "#5c6370";   // Comment colour
    t.linkFg       = "#61afef";   // Type colour
    t.hrColor      = "#4b5263";
    return t;
}

MarkdownTheme MarkdownParser::lightTheme() {
    MarkdownTheme t;
    t.bodyBg       = "#fafafa";   // Atom One Light background
    t.bodyFg       = "#383a42";   // None token colour
    t.headingFg    = "#4078f2";   // Function colour
    t.codeBg       = "#f0f0f0";
    t.codeFg       = "#50a14f";   // String colour (green)
    t.blockquoteBg = "#a0a1a7";   // Comment colour
    t.linkFg       = "#4078f2";   // Function colour
    t.hrColor      = "#d3d3d3";
    return t;
}

// ---------------------------------------------------------------------------
// CSS generation
// ---------------------------------------------------------------------------

std::string MarkdownParser::buildCss(const MarkdownTheme& t) {
    std::ostringstream css;
    css << "body{margin:0;padding:16px 24px;font-family:'Segoe UI',system-ui,sans-serif;"
        << "font-size:14px;line-height:1.7;background:" << t.bodyBg << ";color:" << t.bodyFg << ";}"
        << "h1,h2,h3,h4,h5,h6{color:" << t.headingFg << ";margin:1em 0 .4em;font-weight:600;}"
        << "h1{font-size:2em;border-bottom:1px solid " << t.hrColor << ";padding-bottom:.3em;}"
        << "h2{font-size:1.5em;border-bottom:1px solid " << t.hrColor << ";padding-bottom:.2em;}"
        << "h3{font-size:1.25em;}"
        << "a{color:" << t.linkFg << ";text-decoration:underline;}"
        << "code{background:" << t.codeBg << ";color:" << t.codeFg << ";padding:2px 5px;"
        << "border-radius:3px;font-family:monospace;font-size:0.9em;}"
        << "pre{background:" << t.codeBg << ";color:" << t.codeFg << ";padding:12px 16px;"
        << "border-radius:6px;overflow-x:auto;line-height:1.45;}"
        << "pre code{background:none;padding:0;border-radius:0;font-size:inherit;}"
        << "blockquote{margin:0;padding:0 12px;border-left:4px solid " << t.blockquoteBg << ";"
        << "color:" << t.blockquoteBg << ";}"
        << "ul,ol{padding-left:2em;margin:.5em 0;}"
        << "li{margin:.2em 0;}"
        << "hr{border:none;border-top:1px solid " << t.hrColor << ";margin:1.5em 0;}"
        << "img{max-width:100%;}"
        << "p{margin:.6em 0;}"
        << "strong{font-weight:700;}"
        << "em{font-style:italic;}"
        << "del{text-decoration:line-through;}";
    return css.str();
}

// ---------------------------------------------------------------------------
// HTML escaping
// ---------------------------------------------------------------------------

std::string MarkdownParser::escapeHtml(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (char c : s) {
        switch (c) {
        case '&': out += "&amp;";  break;
        case '<': out += "&lt;";   break;
        case '>': out += "&gt;";   break;
        case '"': out += "&quot;"; break;
        default:  out += c;        break;
        }
    }
    return out;
}

// ---------------------------------------------------------------------------
// Line classification helpers
// ---------------------------------------------------------------------------

static std::string ltrim(const std::string& s) {
    size_t i = 0;
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t')) ++i;
    return s.substr(i);
}

static std::string rtrim(const std::string& s) {
    size_t i = s.size();
    while (i > 0 && (s[i-1] == ' ' || s[i-1] == '\t' || s[i-1] == '\r')) --i;
    return s.substr(0, i);
}

static std::string trim(const std::string& s) { return ltrim(rtrim(s)); }

static bool isBlank(const std::string& s) {
    return s.find_first_not_of(" \t\r") == std::string::npos;
}

bool MarkdownParser::isHRule(const std::string& line) {
    std::string s = trim(line);
    if (s.size() < 3) return false;
    char c = s[0];
    if (c != '-' && c != '*' && c != '_') return false;
    for (char x : s) {
        if (x != c && x != ' ') return false;
    }
    int count = 0;
    for (char x : s) if (x == c) ++count;
    return count >= 3;
}

// Returns heading level 1-6, or 0 if not ATX heading. Fills `content` with heading text.
int MarkdownParser::atxLevel(const std::string& line, std::string& content) {
    int level = 0;
    size_t i = 0;
    while (i < line.size() && line[i] == '#') { ++level; ++i; }
    if (level == 0 || level > 6) return 0;
    if (i < line.size() && line[i] != ' ' && line[i] != '\t') return 0;
    while (i < line.size() && (line[i] == ' ' || line[i] == '\t')) ++i;
    content = trim(line.substr(i));
    // Strip trailing '#'
    size_t j = content.size();
    while (j > 0 && content[j-1] == '#') --j;
    if (j > 0 && (content[j-1] == ' ' || content[j-1] == '\t'))
        content = rtrim(content.substr(0, j));
    return level;
}

// Setext underline: line of '='  or line of '-'.
bool MarkdownParser::isSetextUnder(const std::string& line, char& ch) {
    std::string s = trim(line);
    if (s.size() < 1) return false;
    char c = s[0];
    if (c != '=' && c != '-') return false;
    for (char x : s) if (x != c) return false;
    ch = c;
    return true;
}

// Returns true if `line` starts a fenced code block. `fence` = opening fence (e.g. "```"), `lang` = language tag.
bool MarkdownParser::isFenceOpen(const std::string& line, std::string& fence, std::string& lang) {
    std::string s = ltrim(line);
    char fc = s.empty() ? 0 : s[0];
    if (fc != '`' && fc != '~') return false;
    size_t i = 0;
    while (i < s.size() && s[i] == fc) ++i;
    if (i < 3) return false;
    fence = std::string(i, fc);
    lang = trim(s.substr(i));
    return true;
}

// Returns indent level (0 = not a list), fills `bullet` and `content`.
int MarkdownParser::listIndent(const std::string& line, char& bullet, std::string& content) {
    size_t i = 0;
    int spaces = 0;
    while (i < line.size() && line[i] == ' ') { ++i; ++spaces; }
    if (i >= line.size()) return 0;
    char c = line[i];
    if (c == '-' || c == '*' || c == '+') {
        if (i + 1 < line.size() && (line[i+1] == ' ' || line[i+1] == '\t')) {
            bullet = c;
            content = ltrim(line.substr(i + 1));
            return spaces / 2 + 1;
        }
    }
    // Ordered list: digits followed by '.' or ')'
    size_t j = i;
    while (j < line.size() && std::isdigit(static_cast<unsigned char>(line[j]))) ++j;
    if (j > i && j < line.size() && (line[j] == '.' || line[j] == ')')) {
        if (j + 1 < line.size() && (line[j+1] == ' ' || line[j+1] == '\t')) {
            bullet = '1';
            content = ltrim(line.substr(j + 1));
            return spaces / 2 + 1;
        }
    }
    return 0;
}

bool MarkdownParser::isBlockquote(const std::string& line, std::string& rest) {
    std::string s = ltrim(line);
    if (s.empty() || s[0] != '>') return false;
    size_t i = 1;
    if (i < s.size() && s[i] == ' ') ++i;
    rest = s.substr(i);
    return true;
}

// ---------------------------------------------------------------------------
// Inline rendering (bold, italic, code, links, images)
// ---------------------------------------------------------------------------

std::string MarkdownParser::renderInline(const std::string& s) {
    // We do a simple left-to-right scan for inline markers.
    std::string out;
    out.reserve(s.size() * 2);
    size_t i = 0;
    auto peek = [&](size_t pos, char c) { return pos < s.size() && s[pos] == c; };

    while (i < s.size()) {
        char c = s[i];

        // Image: ![alt](url)
        if (c == '!' && peek(i+1, '[')) {
            size_t j = s.find("](", i+2);
            if (j != std::string::npos) {
                size_t k = s.find(')', j+2);
                if (k != std::string::npos) {
                    std::string alt = s.substr(i+2, j - (i+2));
                    std::string url = s.substr(j+2, k - (j+2));
                    out += "<img src=\"" + escapeHtml(url) + "\" alt=\"" + escapeHtml(alt) + "\">";
                    i = k + 1;
                    continue;
                }
            }
        }

        // Link: [text](url)
        if (c == '[') {
            size_t j = s.find("](", i+1);
            if (j != std::string::npos) {
                size_t k = s.find(')', j+2);
                if (k != std::string::npos) {
                    std::string text = s.substr(i+1, j - (i+1));
                    std::string url  = s.substr(j+2, k - (j+2));
                    out += "<a href=\"" + escapeHtml(url) + "\">" + renderInline(text) + "</a>";
                    i = k + 1;
                    continue;
                }
            }
        }

        // Inline code: `code`
        if (c == '`') {
            // Count consecutive backticks for the opening fence
            size_t cnt = 0;
            while (i + cnt < s.size() && s[i + cnt] == '`') ++cnt;
            std::string fence(cnt, '`');
            size_t j = s.find(fence, i + cnt);
            // Make sure closing fence is exactly cnt backticks (not more)
            if (j != std::string::npos) {
                size_t after = j + cnt;
                bool exactClose = (after >= s.size() || s[after] != '`');
                if (exactClose) {
                    std::string code = s.substr(i + cnt, j - (i + cnt));
                    out += "<code>" + escapeHtml(code) + "</code>";
                    i = after;
                    continue;
                }
            }
            out += escapeHtml(std::string(1, c));
            ++i;
            continue;
        }

        // Bold+Italic: ***text*** or ___text___
        if ((c == '*' || c == '_') && peek(i+1, c) && peek(i+2, c)) {
            size_t j = s.find(std::string(3, c), i+3);
            if (j != std::string::npos) {
                std::string inner = s.substr(i+3, j - (i+3));
                out += "<strong><em>" + renderInline(inner) + "</em></strong>";
                i = j + 3;
                continue;
            }
        }

        // Bold: **text** or __text__
        if ((c == '*' || c == '_') && peek(i+1, c) && !peek(i+2, c)) {
            size_t j = s.find(std::string(2, c), i+2);
            if (j != std::string::npos) {
                std::string inner = s.substr(i+2, j - (i+2));
                out += "<strong>" + renderInline(inner) + "</strong>";
                i = j + 2;
                continue;
            }
        }

        // Italic: *text* or _text_
        if ((c == '*' || c == '_') && !peek(i+1, c)) {
            size_t j = s.find(c, i+1);
            if (j != std::string::npos && j > i+1) {
                std::string inner = s.substr(i+1, j - (i+1));
                out += "<em>" + renderInline(inner) + "</em>";
                i = j + 1;
                continue;
            }
        }

        // Strikethrough: ~~text~~
        if (c == '~' && peek(i+1, '~')) {
            size_t j = s.find("~~", i+2);
            if (j != std::string::npos) {
                std::string inner = s.substr(i+2, j - (i+2));
                out += "<del>" + renderInline(inner) + "</del>";
                i = j + 2;
                continue;
            }
        }

        // Hard line break: two or more spaces before \n — we won't see the newline here,
        // but we can strip trailing spaces and let the caller decide.

        // Everything else: escape and emit
        if (c == '&')       { out += "&amp;";  ++i; continue; }
        if (c == '<')       { out += "&lt;";   ++i; continue; }
        if (c == '>')       { out += "&gt;";   ++i; continue; }
        if (c == '"')       { out += "&quot;"; ++i; continue; }

        out += c;
        ++i;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Block rendering — state machine over lines
// ---------------------------------------------------------------------------

std::string MarkdownParser::renderLines(const std::vector<std::string>& lines) {
    std::ostringstream out;

    enum class State { None, Paragraph, Code, Blockquote, UnorderedList, OrderedList };
    State state = State::None;
    std::string fenceMarker;
    int listDepth = 0;

    auto endBlock = [&] {
        switch (state) {
        case State::Code: out << "</code></pre>\n"; break;
        case State::Paragraph:    out << "</p>\n";  break;
        case State::Blockquote:   out << "</blockquote>\n"; break;
        case State::UnorderedList:
            for (int d = listDepth; d >= 1; --d) out << "</ul>\n";
            break;
        case State::OrderedList:
            for (int d = listDepth; d >= 1; --d) out << "</ol>\n";
            break;
        default: break;
        }
        state = State::None;
        listDepth = 0;
    };

    size_t n = lines.size();
    for (size_t idx = 0; idx < n; ++idx) {
        const std::string& raw = lines[idx];
        const std::string line = rtrim(raw);

        // ---- inside a fenced code block ----
        if (state == State::Code && fenceMarker.empty()) {
            if (raw.compare(0, 4, "    ") == 0 || (!raw.empty() && raw[0] == '\t')) {
                out << escapeHtml(raw.substr(raw[0] == '\t' ? 1 : 4)) << "\n";
                continue;
            }
            endBlock();
        }
        if (state == State::Code) {
            // Check for closing fence
            std::string trimmed = trim(line);
            if (trimmed == fenceMarker ||
                (trimmed.size() >= fenceMarker.size() &&
                 trimmed.substr(0, fenceMarker.size()) == fenceMarker &&
                 trimmed.find_first_not_of(fenceMarker[0]) == std::string::npos)) {
                out << "</code></pre>\n";
                state = State::None;
            } else {
                out << escapeHtml(raw) << "\n";
            }
            continue;
        }

        // ---- blank line ----
        if (isBlank(line)) {
            endBlock();
            continue;
        }

        // ---- ATX heading ----
        std::string headContent;
        int headLevel = atxLevel(line, headContent);
        if (headLevel > 0) {
            endBlock();
            out << "<h" << headLevel << ">" << renderInline(headContent) << "</h" << headLevel << ">\n";
            continue;
        }

        // ---- setext heading (look-ahead at next line) ----
        if (idx + 1 < n) {
            char uch = 0;
            if (isSetextUnder(lines[idx + 1], uch)) {
                endBlock();
                int lvl = (uch == '=') ? 1 : 2;
                out << "<h" << lvl << ">" << renderInline(trim(line)) << "</h" << lvl << ">\n";
                ++idx;   // consume the underline
                continue;
            }
        }

        // ---- horizontal rule ----
        if (isHRule(line)) {
            endBlock();
            out << "<hr>\n";
            continue;
        }

        // ---- fenced code block open ----
        {
            std::string fence, lang;
            if (isFenceOpen(line, fence, lang)) {
                endBlock();
                if (lang.empty())
                    out << "<pre><code>";
                else
                    out << "<pre><code class=\"language-" << escapeHtml(lang) << "\">";
                fenceMarker = fence;
                state = State::Code;
                continue;
            }
        }

        // ---- indented code block (4 spaces or 1 tab) ----
        if ((line.size() >= 4 && line[0] == ' ' && line[1] == ' ' && line[2] == ' ' && line[3] == ' ') ||
            (line.size() >= 1 && line[0] == '\t')) {
            if (state != State::Paragraph && state != State::UnorderedList && state != State::OrderedList) {
                if (state != State::Code) {
                    endBlock();
                    out << "<pre><code>";
                    state = State::Code;
                    fenceMarker = "";   // indented code: no closing fence (blank line ends it)
                }
                // Strip leading 4 spaces or 1 tab
                std::string code = (line[0] == '\t') ? line.substr(1) : line.substr(4);
                out << escapeHtml(code) << "\n";
                continue;
            }
        }

        // ---- blockquote ----
        {
            std::string rest;
            if (isBlockquote(line, rest)) {
                if (state != State::Blockquote) {
                    endBlock();
                    out << "<blockquote>\n";
                    state = State::Blockquote;
                }
                out << "<p>" << renderInline(rest) << "</p>\n";
                continue;
            }
        }

        // ---- list items ----
        {
            char bullet = 0;
            std::string content;
            int depth = listIndent(line, bullet, content);
            if (depth > 0) {
                bool isOrdered = (bullet == '1');
                State want = isOrdered ? State::OrderedList : State::UnorderedList;

                if (state != want) {
                    endBlock();
                    out << (isOrdered ? "<ol>\n" : "<ul>\n");
                    state = want;
                    listDepth = 1;
                }
                // Adjust nesting
                while (listDepth < depth) {
                    out << (isOrdered ? "<ol>\n" : "<ul>\n");
                    ++listDepth;
                }
                while (listDepth > depth) {
                    out << (isOrdered ? "</ol>\n" : "</ul>\n");
                    --listDepth;
                }
                out << "<li>" << renderInline(content) << "</li>\n";
                continue;
            }
        }

        // ---- paragraph ----
        if (state != State::Paragraph) {
            endBlock();
            out << "<p>";
            state = State::Paragraph;
        } else {
            // Hard line break if trailing spaces (already stripped by rtrim, but check raw)
            if (idx > 0 && lines[idx-1].size() >= 2 && lines[idx-1].compare(lines[idx-1].size()-2, 2, "  ") == 0)
                out << "<br>";
            else
                out << " ";
        }
        out << renderInline(trim(line));
    }

    endBlock();
    return out.str();
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

std::string MarkdownParser::toHtml(const std::vector<std::string>& lines, bool isDark) {
    const MarkdownTheme t = isDark ? darkTheme() : lightTheme();
    std::ostringstream html;
    html << "<style>" << buildCss(t) << "</style>\n";
    html << renderLines(lines);
    return html.str();
}

std::string MarkdownParser::toPage(const std::vector<std::string>& lines, bool isDark) {
    const MarkdownTheme t = isDark ? darkTheme() : lightTheme();
    std::ostringstream html;
    html << "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
         << "<style>" << buildCss(t) << "</style>"
         << "</head><body>\n";
    html << renderLines(lines);
    html << "</body></html>";
    return html.str();
}
