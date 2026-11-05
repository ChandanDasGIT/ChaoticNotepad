#include "textengine/docx/docx.h"
#include <cstdlib>
#include <iostream>

static void check(bool ok, const char* what) {
    if (!ok) {
        std::cerr << "Failed: " << what << '\n';
        std::exit(1);
    }
}

int main() {
    // text with tabs, an empty paragraph, accents and characters XML must escape; one style per byte
    const std::string text = "Plain bold\n\n\tTab & <x> caf\xC3\xA9\n";
    std::vector<CharStyle> styles;
    for (char c : text)
        if (c != '\n') styles.push_back(CharStyle{});
    for (size_t i = 6; i < 10; ++i) styles[i].bold = true;              // "bold"
    for (size_t i = styles.size() - 5; i < styles.size(); ++i) {        // " café" (é is two bytes)
        styles[i].italic = true;
        styles[i].underline = true;
    }

    Docx::Content back;
    std::string error;
    check(Docx::read(Docx::write(text, styles), back, error), "read what write made");
    check(back.text == text, "text round trip");
    check(back.styles.size() == styles.size(), "one style per byte");
    for (size_t i = 0; i < styles.size(); ++i) {
        check(back.styles[i].bold == styles[i].bold, "bold round trip");
        check(back.styles[i].italic == styles[i].italic, "italic round trip");
        check(back.styles[i].underline == styles[i].underline, "underline round trip");
    }
    check(!back.lostSomething, "nothing lost");

    check(Docx::read(Docx::write("", {}), back, error) && back.text.empty(), "empty document");
    check(!Docx::read("not a zip file at all, just some text", back, error), "garbage refused");
    check(Docx::isDocxPath("/a/Report.DOCX") && !Docx::isDocxPath("/a/docx"), "extension check");
}
