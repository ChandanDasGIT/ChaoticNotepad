#pragma once
#include <string>
#include <vector>
#include "../textstyle/textstyle.h"

// Word documents (.docx), kept simple: the text of the paragraphs with bold, italic and underline.
// Reading takes word/document.xml out of the zip: each paragraph becomes a line, tabs and line breaks stay.
// Writing makes the smallest valid .docx (three files in a zip) that Word and LibreOffice open.
// Tables, pictures, colours, fonts, headings and the rest are not kept: a .docx saved here holds only
// what the editor shows. Uses zlib for the zip's compression; no Qt.
namespace Docx {

bool isDocxPath(const std::string& path);         // ends with .docx (any case)

struct Content {
    std::string text;                             // UTF-8, '\n' between paragraphs, ends with '\n' (empty: "")
    std::vector<CharStyle> styles;                // one per byte of text that is not '\n', as TextStyle keeps them
    bool lostSomething = false;                   // the file had tables, pictures, notes ... that a save here drops
};

// `bytes` is the whole .docx file. false: not a Word document we can read, `error` says why.
bool read(const std::string& bytes, Content& out, std::string& error);

// The .docx file for this text. `styles` as in Content (missing entries count as plain text).
std::string write(const std::string& text, const std::vector<CharStyle>& styles);

}
