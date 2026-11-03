#pragma once
#include <string>
#include <vector>

// Pure C++17 Markdown → HTML converter.
// No external dependencies (no Qt, no third-party libs).
//
// Supported syntax:
//   ATX headings:        # … ######
//   Setext headings:     underlining with = or -
//   Fenced code blocks:  ```lang … ```  or  ~~~lang … ~~~
//   Indented code:       4+ spaces or 1 tab
//   Inline code:         `code`
//   Bold:                **text** or __text__
//   Italic:              *text* or _text_
//   Bold+italic:         ***text***
//   Strikethrough:       ~~text~~
//   Links:               [text](url)
//   Images:              ![alt](url)
//   Blockquotes:         > …
//   Unordered lists:     - / * / + items
//   Ordered lists:       1. / 2. items
//   Horizontal rules:    ---, ***, ___
//   Paragraph breaks:    blank lines
//   Hard line breaks:    two trailing spaces
//   HTML entities:       < > & " are escaped

struct MarkdownTheme {
    std::string bodyBg;        // page background
    std::string bodyFg;        // default text
    std::string headingFg;     // heading colour
    std::string codeBg;        // inline and block code background
    std::string codeFg;        // code text
    std::string blockquoteBg;  // blockquote left-border accent
    std::string linkFg;        // link colour
    std::string hrColor;       // horizontal rule
};

class MarkdownParser {
public:
    // Convert Markdown lines to a self-contained HTML snippet (no <html>/<body> wrapper —
    // it is meant to be embedded in a Qt WebEngineView or similar container).
    // Pass isDark=true for the dark-theme palette, false for the light-theme palette.
    static std::string toHtml(const std::vector<std::string>& lines, bool isDark);

    // Full self-contained HTML page (with <html>, <head>, <body>) suitable for WebEngineView.
    static std::string toPage(const std::vector<std::string>& lines, bool isDark);

private:
    static MarkdownTheme darkTheme();
    static MarkdownTheme lightTheme();
    static std::string buildCss(const MarkdownTheme& t);
    static std::string renderLines(const std::vector<std::string>& lines);
    static std::string renderInline(const std::string& s);
    static std::string escapeHtml(const std::string& s);
    static bool isHRule(const std::string& line);
    static int atxLevel(const std::string& line, std::string& content);
    static bool isSetextUnder(const std::string& line, char& ch);
    static bool isFenceOpen(const std::string& line, std::string& fence, std::string& lang);
    static int listIndent(const std::string& line, char& bullet, std::string& content);
    static bool isBlockquote(const std::string& line, std::string& rest);
};
