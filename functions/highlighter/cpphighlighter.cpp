#include "cpphighlighter.h"
#include <QTextDocument>

CppHighlighter::CppHighlighter(QObject *parent)
: QSyntaxHighlighter(parent)
{
    HighlightingRule rule;

    // 1. C++ Keywords & Commands
    m_keywordFormat.setForeground(QColor("#c678dd")); // Purple
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
    for (const QString &pattern : keywordPatterns) {
        rule.pattern = QRegularExpression(pattern);
        rule.format = m_keywordFormat;
        m_highlightingRules.append(rule);
    }

    // 2. QML Declarations: 'property' and 'var'
    QTextCharFormat qmlDeclFormat;
    qmlDeclFormat.setForeground(QColor("#e5c07b")); // Warm Gold
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
    m_preprocessorFormat.setForeground(QColor("#61afef")); // Sky Blue
    rule.pattern = QRegularExpression(QStringLiteral("#[a-zA-Z_]+"));
    rule.format = m_preprocessorFormat;
    m_highlightingRules.append(rule);

    // 4. C++ Scope Resolution Operator: word1::word2 (e.g. std::cout, Qt::Key_Up)
    QTextCharFormat scopeFormat;
    scopeFormat.setForeground(QColor("#56b6c2")); // Cyan
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=::)|(?<=::)[A-Za-z_][A-Za-z0-9_]*\\b"));
    rule.format = scopeFormat;
    m_highlightingRules.append(rule);

    // 5. Class / Type Names (PascalCase or Q* types)
    m_classFormat.setFontWeight(QFont::Bold);
    m_classFormat.setForeground(QColor("#e5c07b")); // Golden Yellow
    rule.pattern = QRegularExpression(QStringLiteral("\\bQ[A-Za-z0-9_]+\\b|\\b[A-Z][A-Za-z0-9_]*\\b"));
    rule.format = m_classFormat;
    m_highlightingRules.append(rule);

    // 6. Member / Property Access (words around dot: word.word2)
    QTextCharFormat memberFormat;
    memberFormat.setForeground(QColor("#e06c75")); // Soft Coral / Red
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\.)|(?<=\\.)[A-Za-z_][A-Za-z0-9_]*\\b"));
    rule.format = memberFormat;
    m_highlightingRules.append(rule);

    // 7. Words followed by a colon (e.g. key:, property:, case label:)
    // Excludes C++ scope operator '::'
    QTextCharFormat colonKeyFormat;
    colonKeyFormat.setForeground(QColor("#d19a66")); // Warm Sand / Orange
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*:(?!:))"));
    rule.format = colonKeyFormat;
    m_highlightingRules.append(rule);

    // 8. Words followed by '=' assignment (e.g. let foo = 10; var x = ...)
    // Excludes '==' and '=>'
    QTextCharFormat assignTargetFormat;
    assignTargetFormat.setForeground(QColor("#d19a66")); // Warm Sand / Orange
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*=(?![=>]))"));
    rule.format = assignTargetFormat;
    m_highlightingRules.append(rule);

    // 9. Functions / Words with brackets or braces: word(...), word{...}, word[...]
    m_functionFormat.setForeground(QColor("#61afef")); // Blue
    rule.pattern = QRegularExpression(QStringLiteral("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*[\\(\\{\\[])"));
    rule.format = m_functionFormat;
    m_highlightingRules.append(rule);

    // 10. Numeric literals (Hex, floats, integers)
    m_numberFormat.setForeground(QColor("#98c379")); // Mint Green
    rule.pattern = QRegularExpression(QStringLiteral("\\b0x[0-9a-fA-F]+\\b|\\b[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?\\b"));
    rule.format = m_numberFormat;
    m_highlightingRules.append(rule);

    // 11. Strings
    m_quotationFormat.setForeground(QColor("#98c379")); // Soft Green
    rule.pattern = QRegularExpression(QStringLiteral("\".*?\"|'.*?'"));
    rule.format = m_quotationFormat;
    m_highlightingRules.append(rule);

    // 12. Single-line comments
    m_singleLineCommentFormat.setForeground(QColor("#5c6370")); // Muted Gray
    m_singleLineCommentFormat.setFontItalic(true);
    rule.pattern = QRegularExpression(QStringLiteral("//[^\n]*"));
    rule.format = m_singleLineCommentFormat;
    m_highlightingRules.append(rule);

    // Multi-line comments
    m_multiLineCommentFormat.setForeground(QColor("#5c6370"));
    m_multiLineCommentFormat.setFontItalic(true);
    m_commentStartPattern = QRegularExpression(QStringLiteral("/\\*"));
    m_commentEndPattern = QRegularExpression(QStringLiteral("\\*/"));
}

void CppHighlighter::setDocument(QQuickTextDocument *quickDocument)
{
    if (quickDocument) {
        QSyntaxHighlighter::setDocument(quickDocument->textDocument());
    }
}

QString CppHighlighter::highlightedWord() const
{
    return m_highlightedWord;
}

void CppHighlighter::setHighlightedWord(const QString &word)
{
    if (m_highlightedWord != word) {
        m_highlightedWord = word;
        emit highlightedWordChanged();
        rehighlight();
    }
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
    m_matchedBracket1 = -1;
    m_matchedBracket2 = -1;
    rehighlight();
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
    m_matchedBracket1 = -1;
    m_matchedBracket2 = -1;

    if (!document()) {
        rehighlight();
        return;
    }

    QString docText = document()->toPlainText();
    if (docText.isEmpty()) {
        rehighlight();
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

    rehighlight();
}

void CppHighlighter::highlightBlock(const QString &text)
{
    // Apply normal syntax coloring rules
    for (const HighlightingRule &rule : std::as_const(m_highlightingRules)) {
        QRegularExpressionMatchIterator matchIterator = rule.pattern.globalMatch(text);
        while (matchIterator.hasNext()) {
            QRegularExpressionMatch match = matchIterator.next();
            setFormat(match.capturedStart(), match.capturedLength(), rule.format);
        }
    }

    // Handle multi-line block comments (/* ... */)
    setCurrentBlockState(0);
    int startIndex = 0;
    if (previousBlockState() != 1) {
        startIndex = text.indexOf(m_commentStartPattern);
    }

    while (startIndex >= 0) {
        QRegularExpressionMatch endMatch;
        int endIndex = text.indexOf(m_commentEndPattern, startIndex, &endMatch);
        int commentLength;
        if (endIndex == -1) {
            setCurrentBlockState(1);
            commentLength = text.length() - startIndex;
        } else {
            commentLength = endIndex - startIndex + endMatch.capturedLength();
        }
        setFormat(startIndex, commentLength, m_multiLineCommentFormat);
        startIndex = text.indexOf(m_commentStartPattern, startIndex + commentLength);
    }

    // Word occurrence highlighting (when text is double-clicked/selected)
    if (!m_highlightedWord.trimmed().isEmpty() && m_highlightedWord.length() > 1) {
        QRegularExpression wordRegex(QStringLiteral("\\b") + QRegularExpression::escape(m_highlightedWord) + QStringLiteral("\\b"));
        QRegularExpressionMatchIterator it = wordRegex.globalMatch(text);
        QTextCharFormat wordFormat;
        wordFormat.setBackground(QColor("#3e4451"));
        while (it.hasNext()) {
            QRegularExpressionMatch match = it.next();
            setFormat(match.capturedStart(), match.capturedLength(), wordFormat);
        }
    }

    // Bracket / Brace pair matching highlight
    int blockStart = currentBlock().position();
    int blockEnd = blockStart + text.length();

    QTextCharFormat bracketFormat;
    bracketFormat.setBackground(QColor("#3d4451"));
    bracketFormat.setForeground(QColor("#00e6c3")); // High-visibility teal accent
    bracketFormat.setFontWeight(QFont::Bold);

    if (m_matchedBracket1 >= blockStart && m_matchedBracket1 < blockEnd) {
        setFormat(m_matchedBracket1 - blockStart, 1, bracketFormat);
    }
    if (m_matchedBracket2 >= blockStart && m_matchedBracket2 < blockEnd) {
        setFormat(m_matchedBracket2 - blockStart, 1, bracketFormat);
    }
}
