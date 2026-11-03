#include "markdownsyntax.h"

const LanguageDef& markdownSyntax() {
    static const LanguageDef definition = [] {
        LanguageDef language;
        language.name = "Markdown";
        language.extensions = {"md", "markdown"};
        language.callsAreFunctions = false;
        return language;
    }();
    return definition;
}
