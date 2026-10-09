#include "textsearcher.h"
#include <QRegularExpression>

namespace {

    bool isWordChar(QChar c)
    {
        return c.isLetterOrNumber() || c == QLatin1Char('_');
    }

    // \b only where the query's edge is a word character. "();" or "->" have no
    // word-character edge, so \b would make them impossible to match.
    QString wholeWordPattern(const QString &query)
    {
        QString p = QRegularExpression::escape(query);
        if (isWordChar(query.front()))
            p.prepend(QStringLiteral("\\b"));
        if (isWordChar(query.back()))
            p.append(QStringLiteral("\\b"));
        return p;
    }

} // namespace

TextSearcher::TextSearcher(QObject *parent)
    : QObject(parent)
{
}

QList<int> TextSearcher::findAll(const QString &text, const QString &query, bool caseSensitive, bool wholeWord)
{
    QList<int> matches;
    if (text.isEmpty() || query.isEmpty()) {
        return matches;
    }

    if (wholeWord) {
        const QString pattern = wholeWordPattern(query);
        QRegularExpression::PatternOptions options = QRegularExpression::UseUnicodePropertiesOption;
        if (!caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }

        QRegularExpression regex(pattern, options);
        QRegularExpressionMatchIterator it = regex.globalMatch(text);
        while (it.hasNext()) {
            QRegularExpressionMatch match = it.next();
            matches.append(static_cast<int>(match.capturedStart()));
        }
    } else {
        const Qt::CaseSensitivity cs = caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
        qsizetype pos = 0;
        while ((pos = text.indexOf(query, pos, cs)) != -1) {
            matches.append(static_cast<int>(pos));
            pos += query.length();
        }
    }
    return matches;
}

int TextSearcher::findNext(int currentIndex, int matchCount)
{
    if (matchCount <= 0) return -1;
    return (currentIndex + 1) % matchCount;
}

int TextSearcher::findPrev(int currentIndex, int matchCount)
{
    if (matchCount <= 0) return -1;
    return (currentIndex - 1 + matchCount) % matchCount;
}

QString TextSearcher::replaceSingle(const QString &text, int startIndex, int queryLength, const QString &replacement)
{
    if (startIndex < 0 || startIndex + queryLength > text.length()) {
        return text;
    }
    QString result = text;
    result.replace(startIndex, queryLength, replacement);
    return result;
}

QString TextSearcher::replaceAll(const QString &text, const QString &query, const QString &replacement, bool caseSensitive, bool wholeWord)
{
    if (text.isEmpty() || query.isEmpty()) {
        return text;
    }

    if (wholeWord) {
        const QString pattern = wholeWordPattern(query);
        QRegularExpression::PatternOptions options = QRegularExpression::UseUnicodePropertiesOption;
        if (!caseSensitive) {
            options |= QRegularExpression::CaseInsensitiveOption;
        }

        QRegularExpression regex(pattern, options);
        QString result = text;
        result.replace(regex, replacement);
        return result;
    } else {
        const Qt::CaseSensitivity cs = caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
        QString result = text;
        result.replace(query, replacement, cs);
        return result;
    }
}
