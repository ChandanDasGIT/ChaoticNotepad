#include "textengine/markdown/markdownparser.h"
#include "textengine/syntaxhighlight/syntaxhighlighter.h"
#include <iostream>
#include <cstdlib>

static void contains(const std::string& html, const std::string& expected) {
    if (html.find(expected) == std::string::npos) {
        std::cerr << "Missing: " << expected << "\nIn: " << html << '\n';
        std::exit(1);
    }
}
int main() {
    contains(MarkdownParser::toHtml({"Title", "==="}, true), "<h1>Title</h1>");
    contains(MarkdownParser::toHtml({"first  ", "second"}, true), "first<br>second");
    contains(MarkdownParser::toHtml({"first", "second  "}, true), "first second");
    contains(MarkdownParser::toHtml({"```cpp", "<tag>  "}, true), "&lt;tag&gt;  \n</code></pre>");
    contains(MarkdownParser::toHtml({"~~~", "code", "~~~~", "after"}, true), "</code></pre>\n<p>after</p>");
    contains(MarkdownParser::toHtml({"    one", "    two", "", "after"}, true), "one\ntwo\n</code></pre>\n<p>after</p>");
    contains(MarkdownParser::toHtml({"**bold** *italic* `x<y`"}, false), "<strong>bold</strong> <em>italic</em> <code>x&lt;y</code>");
    contains(MarkdownParser::toHtml({"<script>"}, true), "&lt;script&gt;");
    if (!findLanguage("notes.MD") || findLanguage("notes.markdown")->name != "Markdown") return 1;
}
