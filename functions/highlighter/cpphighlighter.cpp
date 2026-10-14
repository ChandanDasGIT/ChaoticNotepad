#include "cpphighlighter.h"
#include <QTextDocument>
#include <QTextBlock>

CppHighlighter::CppHighlighter(QObject *parent)
: QSyntaxHighlighter(parent)
{
    buildRules();
}

void CppHighlighter::buildRules()
{
    m_highlightingRules.clear();
    const bool dark = m_isDark;
    HighlightingRule rule;

    // 1. C++ Keywords & Commands
    m_keywordFormat.setForeground(QColor(dark ? "#c678dd" : "#a626a4")); // Purple
    m_keywordFormat.setFontWeight(QFont::Bold);
    const QString keywordPatterns[] = {
        QStringLiteral("\\bchar\\b"), QStringLiteral("\\bclass\\b"), QStringLiteral("\\bconst\\b"),
        QStringLiteral("\\bdouble\\b"), QStringLiteral("\\benum\\b"), QStringLiteral("\\bexplicit\\b"),
        QStringLiteral("\\bfriend\\b"), QStringLiteral("\\binline\\b"), QStringLiteral("\\bint\\b"),
        QStringLiteral("\\blong\\b"), QStringLiteral("\\bnamespace\\b"), QStringLiteral("\\boperator\\b"),
        QStringLiteral("\\bprivate\\b"), QStringLiteral("\\bprotected\\b"), QStringLiteral("\\bpublic\\b"),
        QStringLiteral("\\bshort\\b"), QStringLiteral("\\bsignals\\b"), QStringLiteral("\\bsigned\\b"),
        QStringLiteral("\\bslots\\b"), QStringLiteral("\\bstatic\\b"), QStringLiteral("\\bstruct\\b"),
        QStringLiteral("\\btemplate\\b"), QStringLiteral("\\btypedef\\b"), QStringLiteral("\\btypename\\b"),
        QStringLiteral("\\bunion\\b"), QStringLiteral("\\bunsigned\\b"), QStringLiteral("\\bvirtual\\b"),
        QStringLiteral("\\bvoid\\b"), QStringLiteral("\\bvolatile\\b"), QStringLiteral("\\bbool\\b"),
        QStringLiteral("\\bauto\\b"), QStringLiteral("\\bconstexpr\\b"), QStringLiteral("\\bnullptr\\b"),
        QStringLiteral("\\bif\\b"), QStringLiteral("\\belse\\b"), QStringLiteral("\\bfor\\b"),
        QStringLiteral("\\bwhile\\b"), QStringLiteral("\\bdo\\b"), QStringLiteral("\\breturn\\b"),
        QStringLiteral("\\bswitch\\b"), QStringLiteral("\\bcase\\b"), QStringLiteral("\\bbreak\\b"),
        QStringLiteral("\\bcontinue\\b"), QStringLiteral("\\bdefault\\b"), QStringLiteral("\\bnew\\b"),
        QStringLiteral("\\bdelete\\b"), QStringLiteral("\\btry\\b"), QStringLiteral("\\bcatch\\b"),
        QStringLiteral("\\bthrow\\b"), QStringLiteral("\\busing\\b"), QStringLiteral("\\bco_await\\b"),
        QStringLiteral("\\bco_yield\\b"), QStringLiteral("\\bco_return\\b"), QStringLiteral("\\brequires\\b"),
        QStringLiteral("\\bconcept\\b"), QStringLiteral("\\bimport\\b"), QStringLiteral("\\bmodule\\b"),
        QStringLiteral("\\bfunction\\b")
    };
    // One combined regex instead of ~60 separate ones: "\bchar\b" -> "char"
    QStringList keywordWords;
    for (const QString &pattern : keywordPatterns)
        keywordWords << pattern.mid(2, pattern.size() - 4);
    rule.pattern = QRegularExpression(QStringLiteral("\\b(?:") + keywordWords.join(QLatin1Char('|'))
    + QStringLiteral(")\\b"));
    rule.format = m_keywordFormat;
    m_highlightingRules.append(rule);

    // 2. QML Declarations: 'property' and 'var'
    QTextCharFormat qmlDeclFormat;
    qmlDeclFormat.setForeground(QColor(dark ? "#e5c07b" : "#986801")); // Warm Gold
    qmlDeclFormat.setFontWeight(QFont::Bold);
    const QString qmlDeclPatterns[] = {
        QStringLiteral("\\bproperty\\b"),
        QStringLiteral("\\bvar\\b")
    };
    for (const QString &pattern : qmlDeclPatterns) {
        rule.pattern = QRegularExpression(pattern);
        rule.format = qmlDeclFormat;
        m_highlightingRules.append(rule);
    }

    // 3. Preprocessor Directives (#include, #define, #pragma, etc.)
    m_preprocessorFormat.setForeground(QColor(dark ? "#61afef" : "#4078f2")); // Sky Blue
    rule.pattern = QRegularExpression(QStringLiteral("#[a-zA-Z_]+"));
    rule.format = m_preprocessorFormat;
    m_highlightingRules.append(rule);

    // 4. C++ Scope Resolution Operator: word1::word2 (e.g. std::cout, Qt::Key_Up)
    QTextCharFormat scopeFormat;
    scopeFormat.setForeground(QColor(dark ? "#56b6c2" : "#0184bc")); // Cyan
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=::)|(?<=::)[A-Za-z_][A-Za-z0-9_]*\\b"));
    rule.format = scopeFormat;
    m_highlightingRules.append(rule);

    // 5. Class / Type Names (anything starting with a capital letter)
    // Same green as strings / include paths, no bold.
    m_classFormat.setForeground(QColor(dark ? "#98c379" : "#3a8a3d"));
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Z][A-Za-z0-9_]*\\b"));
    rule.format = m_classFormat;
    m_highlightingRules.append(rule);

    // 6. Member / Property Access (words around dot: word.word2)
    QTextCharFormat memberFormat;
    memberFormat.setForeground(QColor(dark ? "#e06c75" : "#e45649")); // Soft Coral / Red
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\.)|(?<=\\.)[A-Za-z_][A-Za-z0-9_]*\\b"));
    rule.format = memberFormat;
    m_highlightingRules.append(rule);

    // 7. Words followed by a colon (e.g. key:, property:, case label:)
    // Excludes C++ scope operator '::'
    QTextCharFormat colonKeyFormat;
    colonKeyFormat.setForeground(QColor(dark ? "#d19a66" : "#b45f06")); // Warm Sand / Orange
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*:(?!:))"));
    rule.format = colonKeyFormat;
    m_highlightingRules.append(rule);

    // 8. Words followed by '=' assignment (e.g. let foo = 10; var x = ...)
    // Excludes '==' and '=>'
    QTextCharFormat assignTargetFormat;
    assignTargetFormat.setForeground(QColor(dark ? "#d19a66" : "#b45f06")); // Warm Sand / Orange
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*=(?![=>]))"));
    rule.format = assignTargetFormat;
    m_highlightingRules.append(rule);

    // 9. Functions / Words with brackets or braces: word(...), word{...}, word[...]
    m_functionFormat.setForeground(QColor(dark ? "#61afef" : "#4078f2")); // Blue
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*[\\(\\{\\[])"));
    rule.format = m_functionFormat;
    m_highlightingRules.append(rule);

    // 10. Numeric literals (Hex, floats, integers)
    m_numberFormat.setForeground(QColor(dark ? "#98c379" : "#3a8a3d")); // Mint Green
    rule.pattern = QRegularExpression(QStringLiteral("\\b0x[0-9a-fA-F]+\\b|\\b[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?\\b"));
    rule.format = m_numberFormat;
    m_highlightingRules.append(rule);

    // 11. Strings
    m_quotationFormat.setForeground(QColor(dark ? "#98c379" : "#3a8a3d")); // Soft Green
    rule.pattern = QRegularExpression(QStringLiteral("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'"));
    rule.format = m_quotationFormat;
    m_highlightingRules.append(rule);

    // Comment formats. Comments are NOT regex rules: they are found by a small
    // scanner in applyCommentFormats() that runs after all the rules above,
    // so they always override them (and ignore comment tokens inside strings).
    m_singleLineCommentFormat.setForeground(QColor(dark ? "#5c6370" : "#8a8d96")); // Muted Gray
    m_singleLineCommentFormat.setFontItalic(true);
    m_multiLineCommentFormat.setForeground(QColor(dark ? "#5c6370" : "#8a8d96"));
    m_multiLineCommentFormat.setFontItalic(true);

    applyLanguage();
}

void CppHighlighter::setDocument(QQuickTextDocument *quickDocument)
{
    if (quickDocument) {
        QSyntaxHighlighter::setDocument(quickDocument->textDocument());
    } else {
        QSyntaxHighlighter::setDocument(nullptr);
    }
}

QString CppHighlighter::filePath() const
{
    return m_filePath;
}

void CppHighlighter::setFilePath(const QString &path)
{
    if (m_filePath == path) return;
    m_filePath = path;
    emit filePathChanged();

    const QString p = path.toLower();
    Language lang = Language::Cpp;
    if (p.endsWith(QStringLiteral(".lua")))       lang = Language::Lua;
    else if (p.endsWith(QStringLiteral(".fish"))) lang = Language::Fish;

    if (lang != m_language) {
        m_language = lang;
        applyLanguage();
        rehighlight();
    }
}

bool CppHighlighter::isDark() const
{
    return m_isDark;
}

void CppHighlighter::setIsDark(bool dark)
{
    if (m_isDark == dark) return;
    m_isDark = dark;
    buildRules();
    emit isDarkChanged();
    rehighlight();
}

void CppHighlighter::applyLanguage()
{
    switch (m_language) {
        case Language::Lua:
            m_lineCommentToken = QStringLiteral("--");
            m_blockStartToken  = QStringLiteral("--[[");
            m_blockEndToken    = QStringLiteral("]]");
            break;
        case Language::Fish:
            m_lineCommentToken = QStringLiteral("#");
            m_blockStartToken.clear();
            m_blockEndToken.clear();
            break;
        case Language::Cpp:
        default:
            m_lineCommentToken = QStringLiteral("//");
            m_blockStartToken  = QStringLiteral("/*");
            m_blockEndToken    = QStringLiteral("*/");
            break;
    }
}

QString CppHighlighter::highlightedWord() const
{
    return m_highlightedWord;
}

void CppHighlighter::setHighlightedWord(const QString &word)
{
    if (m_highlightedWord == word) return;

    const QString oldWord = m_highlightedWord;
    m_highlightedWord = word;
    m_wordRegex = (word.trimmed().isEmpty() || word.length() <= 1)
    ? QRegularExpression()
    : QRegularExpression(QStringLiteral("\\b") + QRegularExpression::escape(word)
    + QStringLiteral("\\b"));
    emit highlightedWordChanged();

    QTextDocument *doc = document();
    if (!doc) return;

    // Only the lines that contain the old or the new word need to be redone
    QVector<QTextBlock> hits;
    for (QTextBlock b = doc->begin(); b.isValid(); b = b.next()) {
        const QString t = b.text();
        if ((!oldWord.isEmpty() && t.contains(oldWord)) || (!word.isEmpty() && t.contains(word))) {
            hits.append(b);
            if (hits.size() > 300) break;
        }
    }
    if (hits.size() > 300) {      // a very common word: one full pass is cheaper
        rehighlight();
        return;
    }
    for (const QTextBlock &b : std::as_const(hits))
        rehighlightBlock(b);
}

int CppHighlighter::cursorPosition() const
{
    return m_cursorPosition;
}

void CppHighlighter::setCursorPosition(int pos)
{
    if (m_cursorPosition != pos) {
        m_cursorPosition = pos;
        emit cursorPositionChanged();
        updateBracketMatching();
    }
}

void CppHighlighter::clearBracketMatches()
{
    int oldPos1 = m_matchedBracket1;
    int oldPos2 = m_matchedBracket2;

    m_matchedBracket1 = -1;
    m_matchedBracket2 = -1;

    if (!document()) return;

    if (oldPos1 >= 0) {
        QTextBlock b = document()->findBlock(oldPos1);
        if (b.isValid()) rehighlightBlock(b);
    }
    if (oldPos2 >= 0) {
        QTextBlock b = document()->findBlock(oldPos2);
        if (b.isValid()) rehighlightBlock(b);
    }
}

int CppHighlighter::findMatchingBracket(const QString &docText, int index, QChar openChar, QChar closeChar, bool forward)
{
    int depth = 0;
    int step = forward ? 1 : -1;
    int i = index;

    while (i >= 0 && i < docText.length()) {
        QChar c = docText.at(i);
        if (c == openChar) {
            depth++;
        } else if (c == closeChar) {
            depth--;
            if (depth == 0) {
                return i;
            }
        }
        i += step;
    }
    return -1;
}

void CppHighlighter::updateBracketMatching()
{
    // Bracket matching is currently disabled (kept as in the original code).
    // Remove this early return to re-enable it.
    return;

    // Save previous matched bracket positions so we can clear their highlights
    int oldPos1 = m_matchedBracket1;
    int oldPos2 = m_matchedBracket2;

    m_matchedBracket1 = -1;
    m_matchedBracket2 = -1;

    auto refreshBlocks = [this](int pos1, int pos2) {
        if (!document()) return;
        if (pos1 >= 0) {
            QTextBlock b = document()->findBlock(pos1);
            if (b.isValid()) rehighlightBlock(b);
        }
        if (pos2 >= 0) {
            QTextBlock b = document()->findBlock(pos2);
            if (b.isValid()) rehighlightBlock(b);
        }
    };

    if (!document()) {
        refreshBlocks(oldPos1, oldPos2);
        return;
    }

    QString docText = document()->toPlainText();
    if (docText.isEmpty()) {
        refreshBlocks(oldPos1, oldPos2);
        return;
    }

    int checkPos = -1;

    // Check character directly under cursor or directly before cursor
    if (m_cursorPosition < docText.length()) {
        QChar ch = docText.at(m_cursorPosition);
        if (ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']') {
            checkPos = m_cursorPosition;
        }
    }
    if (checkPos == -1 && m_cursorPosition > 0 && m_cursorPosition <= docText.length()) {
        QChar prevCh = docText.at(m_cursorPosition - 1);
        if (prevCh == '{' || prevCh == '}' || prevCh == '(' || prevCh == ')' || prevCh == '[' || prevCh == ']') {
            checkPos = m_cursorPosition - 1;
        }
    }

    if (checkPos != -1) {
        QChar ch = docText.at(checkPos);
        int partner = -1;

        if (ch == '{') partner = findMatchingBracket(docText, checkPos, '{', '}', true);
        else if (ch == '}') partner = findMatchingBracket(docText, checkPos, '}', '{', false);
        else if (ch == '(') partner = findMatchingBracket(docText, checkPos, '(', ')', true);
        else if (ch == ')') partner = findMatchingBracket(docText, checkPos, ')', '(', false);
        else if (ch == '[') partner = findMatchingBracket(docText, checkPos, '[', ']', true);
        else if (ch == ']') partner = findMatchingBracket(docText, checkPos, ']', '[', false);

        if (partner != -1) {
            m_matchedBracket1 = checkPos;
            m_matchedBracket2 = partner;
        }
    }

    // Only repaint if the matched positions actually changed
    if (oldPos1 != m_matchedBracket1 || oldPos2 != m_matchedBracket2) {
        refreshBlocks(oldPos1, oldPos2);
        refreshBlocks(m_matchedBracket1, m_matchedBracket2);
    }
}

// Scans the block for comments and paints them over whatever the regex rules
// produced. Skips comment tokens that appear inside string / char literals and
// carries block-comment state across lines via the block state.
void CppHighlighter::applyCommentFormats(const QString &text)
{
    const bool hasBlock = !m_blockStartToken.isEmpty();
    const int n = text.length();
    int i = 0;
    bool inBlock = hasBlock && previousBlockState() == 1;

    setCurrentBlockState(0);

    while (i < n) {
        if (inBlock) {
            const int end = text.indexOf(m_blockEndToken, i);
            if (end == -1) {
                setFormat(i, n - i, m_multiLineCommentFormat);
                setCurrentBlockState(1);
                return;
            }
            const int len = end + m_blockEndToken.length() - i;
            setFormat(i, len, m_multiLineCommentFormat);
            i += len;
            inBlock = false;
            continue;
        }

        const QChar c = text.at(i);

        // Skip string / char literals so "http://x" is not a comment
        if (c == QLatin1Char('"') || c == QLatin1Char('\'')) {
            int j = i + 1;
            while (j < n && text.at(j) != c) {
                if (text.at(j) == QLatin1Char('\\')) ++j;
                ++j;
            }
            i = j + 1;
            continue;
        }

        // Block start must be tested before the line token (Lua: "--[[" vs "--")
        if (hasBlock && text.mid(i, m_blockStartToken.length()) == m_blockStartToken) {
            setFormat(i, m_blockStartToken.length(), m_multiLineCommentFormat);
            i += m_blockStartToken.length();
            inBlock = true;
            continue;
        }

        if (text.mid(i, m_lineCommentToken.length()) == m_lineCommentToken) {
            setFormat(i, n - i, m_singleLineCommentFormat);
            return;
        }

        ++i;
    }
}

void CppHighlighter::highlightBlock(const QString &text)
{
    // 1. Normal syntax coloring rules
    for (const HighlightingRule &rule : std::as_const(m_highlightingRules)) {
        QRegularExpressionMatchIterator matchIterator = rule.pattern.globalMatch(text);
        while (matchIterator.hasNext()) {
            QRegularExpressionMatch match = matchIterator.next();
            setFormat(match.capturedStart(), match.capturedLength(), rule.format);
        }
    }

    // 2. Comments last, so they override every rule above
    applyCommentFormats(text);

    // 3. Word occurrence highlighting (background only, keeps the text color)
    if (!m_wordRegex.pattern().isEmpty() && text.contains(m_highlightedWord)) {
        QRegularExpressionMatchIterator it = m_wordRegex.globalMatch(text);
        while (it.hasNext()) {
            QRegularExpressionMatch match = it.next();
            for (int k = match.capturedStart(); k < match.capturedEnd(); ++k) {
                QTextCharFormat f = format(k);
                f.setBackground(QColor(m_isDark ? "#3e4451" : "#d6e4f7"));
                setFormat(k, 1, f);
            }
        }
    }

    // 4. Bracket / Brace pair matching highlight
    int blockStart = currentBlock().position();
    int blockEnd = blockStart + text.length();

    QTextCharFormat bracketFormat;
    bracketFormat.setBackground(QColor(m_isDark ? "#3d4451" : "#d6e4f7"));
    bracketFormat.setForeground(QColor(m_isDark ? "#00e6c3" : "#007a66"));
    bracketFormat.setFontWeight(QFont::Bold);

    if (m_matchedBracket1 >= blockStart && m_matchedBracket1 < blockEnd) {
        setFormat(m_matchedBracket1 - blockStart, 1, bracketFormat);
    }
    if (m_matchedBracket2 >= blockStart && m_matchedBracket2 < blockEnd) {
        setFormat(m_matchedBracket2 - blockStart, 1, bracketFormat);
    }
}
