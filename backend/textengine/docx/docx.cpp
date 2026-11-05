#include "docx.h"
#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <zlib.h>

namespace {

// ---------------------------------------------------------------- zip

constexpr uint32_t kLocalSig = 0x04034b50;
constexpr uint32_t kCentralSig = 0x02014b50;
constexpr uint32_t kEndSig = 0x06054b50;
constexpr size_t kMaxPart = 256u * 1024u * 1024u;     // a document.xml bigger than this is refused

uint32_t le16(const std::string& b, size_t at) {
    return static_cast<uint32_t>(static_cast<unsigned char>(b[at])) |
           static_cast<uint32_t>(static_cast<unsigned char>(b[at + 1])) << 8;
}
uint32_t le32(const std::string& b, size_t at) { return le16(b, at) | le16(b, at + 2) << 16; }

void put16(std::string& b, uint32_t v) {
    b += static_cast<char>(v & 0xff);
    b += static_cast<char>((v >> 8) & 0xff);
}
void put32(std::string& b, uint32_t v) {
    put16(b, v & 0xffff);
    put16(b, v >> 16);
}

uint32_t crcOf(const std::string& data) {
    return static_cast<uint32_t>(crc32(0L, reinterpret_cast<const Bytef*>(data.data()), static_cast<uInt>(data.size())));
}

bool inflateRaw(const char* data, size_t size, size_t expected, std::string& out) {
    z_stream z{};
    if (inflateInit2(&z, -MAX_WBITS) != Z_OK) return false;
    out.assign(expected, '\0');
    z.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(data));
    z.avail_in = static_cast<uInt>(size);
    z.next_out = reinterpret_cast<Bytef*>(out.data());
    z.avail_out = static_cast<uInt>(expected);
    int r = inflate(&z, Z_FINISH);
    const size_t produced = z.total_out;
    inflateEnd(&z);
    if (r != Z_STREAM_END || produced != expected) return false;
    return true;
}

std::string deflateRaw(const std::string& data) {
    z_stream z{};
    deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY);
    std::string out(deflateBound(&z, static_cast<uLong>(data.size())), '\0');
    z.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(data.data()));
    z.avail_in = static_cast<uInt>(data.size());
    z.next_out = reinterpret_cast<Bytef*>(out.data());
    z.avail_out = static_cast<uInt>(out.size());
    deflate(&z, Z_FINISH);
    out.resize(z.total_out);
    deflateEnd(&z);
    return out;
}

struct Entry {
    std::string name;
    uint32_t method = 0, crc = 0, packed = 0, size = 0, local = 0;
};

bool listZip(const std::string& b, std::vector<Entry>& out, std::string& error) {
    error = "it is not a Word document (no zip directory)";
    if (b.size() < 22) return false;
    size_t end = std::string::npos;
    const size_t lowest = b.size() > 22 + 65535 ? b.size() - 22 - 65535 : 0;
    for (size_t i = b.size() - 22 + 1; i-- > lowest;)
        if (le32(b, i) == kEndSig) { end = i; break; }
    if (end == std::string::npos) return false;

    const uint32_t count = le16(b, end + 10);
    size_t at = le32(b, end + 16);
    for (uint32_t n = 0; n < count; ++n) {
        if (at + 46 > b.size() || le32(b, at) != kCentralSig) return false;
        Entry e;
        e.method = le16(b, at + 10);
        e.crc = le32(b, at + 16);
        e.packed = le32(b, at + 20);
        e.size = le32(b, at + 24);
        const size_t nameLen = le16(b, at + 28), extra = le16(b, at + 30), comment = le16(b, at + 32);
        e.local = le32(b, at + 42);
        if (at + 46 + nameLen > b.size()) return false;
        e.name = b.substr(at + 46, nameLen);
        out.push_back(std::move(e));
        at += 46 + nameLen + extra + comment;
    }
    error.clear();
    return true;
}

bool extract(const std::string& b, const Entry& e, std::string& out, std::string& error) {
    error = "the Word document is damaged (" + e.name + ")";
    if (e.packed == 0xffffffffu || e.size == 0xffffffffu || e.local == 0xffffffffu) { error = "the Word document is too big"; return false; }
    if (e.size > kMaxPart) { error = "the Word document is too big"; return false; }
    if (static_cast<size_t>(e.local) + 30 > b.size() || le32(b, e.local) != kLocalSig) return false;
    const size_t data = static_cast<size_t>(e.local) + 30 + le16(b, e.local + 26) + le16(b, e.local + 28);
    if (data + e.packed > b.size()) return false;
    if (e.method == 0) {
        if (e.packed != e.size) return false;
        out = b.substr(data, e.size);
    } else if (e.method == 8) {
        if (!inflateRaw(b.data() + data, e.packed, e.size, out)) return false;
    } else {
        error = "the Word document uses a compression this app cannot read";
        return false;
    }
    if (crcOf(out) != e.crc) return false;
    error.clear();
    return true;
}

void addEntry(std::string& zip, std::string& central, const std::string& name, const std::string& data) {
    const std::string packed = deflateRaw(data);
    const uint32_t crc = crcOf(data);
    const uint32_t offset = static_cast<uint32_t>(zip.size());
    auto header = [&](std::string& b, bool isCentral) {
        put32(b, isCentral ? kCentralSig : kLocalSig);
        if (isCentral) put16(b, 20);                      // made by
        put16(b, 20);                                     // needed to extract
        put16(b, 0);                                      // flags
        put16(b, 8);                                      // deflate
        put16(b, 0);                                      // time
        put16(b, 0x21);                                   // date: 1980-01-01
        put32(b, crc);
        put32(b, static_cast<uint32_t>(packed.size()));
        put32(b, static_cast<uint32_t>(data.size()));
        put16(b, static_cast<uint32_t>(name.size()));
        put16(b, 0);                                      // extra
        if (isCentral) {
            put16(b, 0);                                  // comment
            put16(b, 0);                                  // disk
            put16(b, 0);                                  // internal attributes
            put32(b, 0);                                  // external attributes
            put32(b, offset);
        }
        b += name;
    };
    header(zip, false);
    zip += packed;
    header(central, true);
}

// ---------------------------------------------------------------- xml

std::string decodeEntities(const std::string& s) {
    if (s.find('&') == std::string::npos) return s;
    std::string out;
    out.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] != '&') { out += s[i]; continue; }
        const size_t semi = s.find(';', i);
        if (semi == std::string::npos || semi - i > 12) { out += s[i]; continue; }
        const std::string name = s.substr(i + 1, semi - i - 1);
        unsigned long cp = 0;
        if (name == "lt") cp = '<';
        else if (name == "gt") cp = '>';
        else if (name == "amp") cp = '&';
        else if (name == "quot") cp = '"';
        else if (name == "apos") cp = '\'';
        else if (name.size() > 1 && name[0] == '#') {
            try {
                cp = name[1] == 'x' || name[1] == 'X' ? std::stoul(name.substr(2), nullptr, 16) : std::stoul(name.substr(1));
            } catch (...) { cp = 0; }
        }
        if (cp == 0 || cp > 0x10FFFF) { out += s[i]; continue; }
        if (cp < 0x80) out += static_cast<char>(cp);
        else if (cp < 0x800) { out += static_cast<char>(0xC0 | (cp >> 6)); out += static_cast<char>(0x80 | (cp & 0x3F)); }
        else if (cp < 0x10000) {
            out += static_cast<char>(0xE0 | (cp >> 12));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        } else {
            out += static_cast<char>(0xF0 | (cp >> 18));
            out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        }
        i = semi;
    }
    return out;
}

// the value of attribute `name` (e.g. "w:val") in the inside of a tag, or "" with found = false
std::string attribute(const std::string& tag, const std::string& name, bool& found) {
    found = false;
    size_t at = 0;
    while ((at = tag.find(name, at)) != std::string::npos) {
        const bool startsName = at > 0 && (tag[at - 1] == ' ' || tag[at - 1] == '\t' || tag[at - 1] == '\n' || tag[at - 1] == '\r');
        size_t p = at + name.size();
        while (p < tag.size() && (tag[p] == ' ' || tag[p] == '\t' || tag[p] == '\n' || tag[p] == '\r')) ++p;
        if (startsName && p < tag.size() && tag[p] == '=') {
            ++p;
            while (p < tag.size() && (tag[p] == ' ' || tag[p] == '\t' || tag[p] == '\n' || tag[p] == '\r')) ++p;
            if (p < tag.size() && (tag[p] == '"' || tag[p] == '\'')) {
                const size_t close = tag.find(tag[p], p + 1);
                if (close == std::string::npos) return "";
                found = true;
                return decodeEntities(tag.substr(p + 1, close - p - 1));
            }
        }
        at += name.size();
    }
    return "";
}

std::string localName(const std::string& qname) {
    const size_t colon = qname.find(':');
    return colon == std::string::npos ? qname : qname.substr(colon + 1);
}

// The prefix bound to WordprocessingML ("w" in practically every file).
std::string wordPrefix(const std::string& xml) {
    for (const char* ns : {"http://schemas.openxmlformats.org/wordprocessingml/2006/main", "http://purl.oclc.org/ooxml/wordprocessingml/main"}) {
        const std::string quoted = std::string("=\"") + ns + "\"";
        size_t at = xml.find(quoted);
        if (at == std::string::npos) continue;
        const size_t start = xml.rfind("xmlns:", at);
        if (start != std::string::npos && start + 6 <= at) return xml.substr(start + 6, at - start - 6);
    }
    return "w";
}

bool isOff(const std::string& tag, const std::string& valName, bool underline) {
    bool found = false;
    const std::string v = attribute(tag, valName, found);
    if (!found) return false;
    if (underline) return v == "none";
    return v == "0" || v == "false" || v == "off";
}

void parseDocument(const std::string& xml, Docx::Content& out) {
    const std::string w = wordPrefix(xml);
    const std::string W = w + ":";
    const std::string val = W + "val";

    CharStyle run;                 // the formatting of the run being read
    bool inRun = false;
    bool inText = false;           // inside <w:t>: its characters are the document's text
    int skip = 0;                  // inside something whose content is not shown (paragraph settings, old revisions, fallbacks)
    int inRunProps = 0;

    auto append = [&](const std::string& s) {
        for (char c : s) {
            if (c == '\r') continue;
            out.text += c;
            if (c != '\n') out.styles.push_back(run);
        }
    };

    size_t i = 0;
    while (i < xml.size()) {
        if (xml[i] != '<') {
            const size_t next = xml.find('<', i);
            const size_t stop = next == std::string::npos ? xml.size() : next;
            if (inText && skip == 0) append(decodeEntities(xml.substr(i, stop - i)));
            i = stop;
            continue;
        }
        if (xml.compare(i, 4, "<!--") == 0) {
            const size_t e = xml.find("-->", i + 4);
            i = e == std::string::npos ? xml.size() : e + 3;
            continue;
        }
        if (xml.compare(i, 9, "<![CDATA[") == 0) {
            const size_t e = xml.find("]]>", i + 9);
            const size_t stop = e == std::string::npos ? xml.size() : e;
            if (inText && skip == 0) append(xml.substr(i + 9, stop - i - 9));
            i = e == std::string::npos ? xml.size() : e + 3;
            continue;
        }
        if (xml.compare(i, 2, "<?") == 0 || xml.compare(i, 2, "<!") == 0) {
            const size_t e = xml.find('>', i);
            i = e == std::string::npos ? xml.size() : e + 1;
            continue;
        }

        // a tag: find its end, minding quoted attribute values
        size_t e = i + 1;
        char quote = 0;
        while (e < xml.size() && (quote || xml[e] != '>')) {
            if (quote) { if (xml[e] == quote) quote = 0; }
            else if (xml[e] == '"' || xml[e] == '\'') quote = xml[e];
            ++e;
        }
        if (e >= xml.size()) break;
        const bool closing = xml[i + 1] == '/';
        const bool selfClosing = xml[e - 1] == '/';
        const std::string inside = xml.substr(i + (closing ? 2 : 1), e - i - (closing ? 2 : 1) - (selfClosing ? 1 : 0));
        size_t nameEnd = 0;
        while (nameEnd < inside.size() && !std::strchr(" \t\r\n", inside[nameEnd])) ++nameEnd;
        const std::string qname = inside.substr(0, nameEnd);
        i = e + 1;

        const bool isWord = qname.compare(0, W.size(), W) == 0;
        const std::string name = isWord ? qname.substr(W.size()) : std::string();
        const std::string local = localName(qname);

        // parts whose content is not text of the document
        const bool hides = (isWord && (name == "pPr" || name == "rPrChange" || name == "sectPr" || name == "tblPr" ||
                                       name == "trPr" || name == "tcPr" || name == "tblGrid")) ||
                           (!isWord && local == "Fallback");
        if (hides) {
            if (selfClosing) continue;
            if (closing) { if (skip > 0) --skip; }
            else ++skip;
            continue;
        }
        if (!isWord) continue;

        if (name == "tbl" || name == "drawing" || name == "pict" || name == "object" ||
            name == "footnoteReference" || name == "endnoteReference")
            out.lostSomething = true;
        if (skip > 0) continue;

        if (name == "p") {
            if (closing || selfClosing) { run = CharStyle{}; append("\n"); }
        } else if (name == "r") {
            if (!closing && !selfClosing) { inRun = true; run = CharStyle{}; }
            else { inRun = false; run = CharStyle{}; }
        } else if (name == "rPr") {
            if (selfClosing) continue;
            inRunProps += closing ? -1 : 1;
        } else if (inRunProps > 0 && inRun && !closing) {
            if (name == "b") run.bold = !isOff(inside, val, false);
            else if (name == "i") run.italic = !isOff(inside, val, false);
            else if (name == "u") run.underline = !isOff(inside, val, true);
        } else if (name == "t") {
            inText = !closing && !selfClosing;
        } else if (!closing && inRun) {
            if (name == "tab") append("\t");
            else if (name == "br" || name == "cr") append("\n");
            else if (name == "noBreakHyphen") append("-");
        }
    }
}

std::string officeDocumentPath(const std::string& rels) {
    size_t at = 0;
    while ((at = rels.find("<Relationship ", at)) != std::string::npos) {
        const size_t end = rels.find('>', at);
        if (end == std::string::npos) break;
        const std::string tag = " " + rels.substr(at + 14, end - at - 14);
        bool found = false;
        const std::string type = attribute(tag, "Type", found);
        if (type.size() >= 15 && type.compare(type.size() - 15, 15, "/officeDocument") == 0) {
            std::string target = attribute(tag, "Target", found);
            while (!target.empty() && target[0] == '/') target.erase(0, 1);
            if (!target.empty()) return target;
        }
        at = end;
    }
    return "word/document.xml";
}

void escapeInto(std::string& out, const std::string& s) {
    for (char c : s) {
        switch (c) {
        case '&': out += "&amp;"; break;
        case '<': out += "&lt;"; break;
        case '>': out += "&gt;"; break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) break;     // not allowed in XML
            out += c;
        }
    }
}

bool sameLook(const CharStyle& a, const CharStyle& b) {
    return a.bold == b.bold && a.italic == b.italic && a.underline == b.underline;
}

}  // namespace

namespace Docx {

bool isDocxPath(const std::string& path) {
    if (path.size() < 5) return false;
    std::string ext = path.substr(path.size() - 5);
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return ext == ".docx";
}

bool read(const std::string& bytes, Content& out, std::string& error) {
    out = Content{};
    if (bytes.empty()) return true;                       // an empty file: an empty document
    std::vector<Entry> entries;
    if (!listZip(bytes, entries, error)) return false;

    auto find = [&](const std::string& name) -> const Entry* {
        for (const Entry& e : entries)
            if (e.name == name) return &e;
        return nullptr;
    };
    std::string mainPath = "word/document.xml";
    if (const Entry* rels = find("_rels/.rels")) {
        std::string relsXml;
        if (extract(bytes, *rels, relsXml, error)) mainPath = officeDocumentPath(relsXml);
    }
    const Entry* main = find(mainPath);
    if (!main) main = find("word/document.xml");
    if (!main) { error = "it is not a Word document (no word/document.xml)"; return false; }

    std::string xml;
    if (!extract(bytes, *main, xml, error)) return false;
    parseDocument(xml, out);
    for (const Entry& e : entries)
        if (e.name.compare(0, 11, "word/header") == 0 || e.name.compare(0, 11, "word/footer") == 0) out.lostSomething = true;

    if (out.text.find('\0') != std::string::npos) { error = "the Word document has text this app cannot show"; return false; }
    // one empty paragraph is an empty document
    if (out.text == "\n") out.text.clear();
    return true;
}

std::string write(const std::string& text, const std::vector<CharStyle>& styles) {
    std::string body;
    body.reserve(text.size() * 2 + 256);

    // one paragraph per line; the newline at the very end does not start another one
    const size_t stop = !text.empty() && text.back() == '\n' ? text.size() - 1 : text.size();
    size_t k = 0;                                       // index into styles
    size_t pos = 0;
    while (true) {
        size_t end = text.find('\n', pos);
        if (end == std::string::npos || end > stop) end = stop;

        if (end == pos) {
            body += "<w:p/>";
        } else {
            body += "<w:p>";
            size_t i = pos;
            while (i < end) {
                const CharStyle look = k < styles.size() ? styles[k] : CharStyle{};
                std::string chunk;                      // the run's characters
                while (i < end) {
                    const bool lead = (static_cast<unsigned char>(text[i]) & 0xC0) != 0x80;
                    const CharStyle here = k < styles.size() ? styles[k] : CharStyle{};
                    if (lead && !chunk.empty() && !sameLook(here, look)) break;
                    chunk += text[i];
                    ++i;
                    ++k;
                }
                body += "<w:r>";
                if (look.bold || look.italic || look.underline) {
                    body += "<w:rPr>";
                    if (look.bold) body += "<w:b/>";
                    if (look.italic) body += "<w:i/>";
                    if (look.underline) body += "<w:u w:val=\"single\"/>";
                    body += "</w:rPr>";
                }
                size_t a = 0;
                while (a < chunk.size()) {
                    size_t tab = chunk.find('\t', a);
                    if (tab == std::string::npos) tab = chunk.size();
                    if (tab > a) {
                        body += "<w:t xml:space=\"preserve\">";
                        escapeInto(body, chunk.substr(a, tab - a));
                        body += "</w:t>";
                    }
                    if (tab < chunk.size()) body += "<w:tab/>";
                    a = tab + 1;
                }
                body += "</w:r>";
            }
            body += "</w:p>";
        }
        if (end >= stop) break;
        pos = end + 1;
    }

    const std::string document =
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>" +
        body + "</w:body></w:document>";
    const std::string types =
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        "<Override PartName=\"/word/document.xml\" "
        "ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
        "</Types>";
    const std::string rels =
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        "<Relationship Id=\"rId1\" "
        "Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" "
        "Target=\"word/document.xml\"/></Relationships>";

    std::string zip, central;
    addEntry(zip, central, "[Content_Types].xml", types);
    addEntry(zip, central, "_rels/.rels", rels);
    addEntry(zip, central, "word/document.xml", document);
    const uint32_t centralAt = static_cast<uint32_t>(zip.size());
    zip += central;
    put32(zip, kEndSig);
    put16(zip, 0);
    put16(zip, 0);
    put16(zip, 3);
    put16(zip, 3);
    put32(zip, static_cast<uint32_t>(central.size()));
    put32(zip, centralAt);
    put16(zip, 0);
    return zip;
}

}  // namespace Docx
