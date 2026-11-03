#pragma once
#include "languagedef.h"

const LanguageDef& markdownSyntax();
inline const bool markdownSyntaxRegistered = registerLanguage(markdownSyntax());
