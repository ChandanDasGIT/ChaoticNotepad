#pragma once

#include <QSyntaxHighlighter>
#include <QRegularExpression>
#include <QTextCharFormat>
#include <QQuickTextDocument>
#include <QColor>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class CppHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString highlightedWord READ highlightedWord WRITE setHighlightedWord NOTIFY highlightedWordChanged)
    Q_PROPERTY(int cursorPosition READ cursorPosition WRITE setCursorPosition NOTIFY cursorPositionChanged)

public:
    explicit CppHighlighter(QObject *parent = nullptr);

    Q_INVOKABLE void setDocument(QQuickTextDocument *quickDocument);
    Q_INVOKABLE void clearBracketMatches();

    QString highlightedWord() const;
    void setHighlightedWord(const QString &word);

    int cursorPosition() const;
    void setCursorPosition(int pos);

signals:
    void highlightedWordChanged();
    void cursorPositionChanged();

protected:
    void highlightBlock(const QString &text) override;

private:
    struct HighlightingRule {
        QRegularExpression pattern;
        QTextCharFormat format;
    };
    QVector<HighlightingRule> m_highlightingRules;

    QRegularExpression m_commentStartPattern;
    QRegularExpression m_commentEndPattern;

    QTextCharFormat m_keywordFormat;
    QTextCharFormat m_classFormat;
    QTextCharFormat m_singleLineCommentFormat;
    QTextCharFormat m_multiLineCommentFormat;
    QTextCharFormat m_quotationFormat;
    QTextCharFormat m_functionFormat;
    QTextCharFormat m_numberFormat;
    QTextCharFormat m_preprocessorFormat;

    QString m_highlightedWord;
    int m_cursorPosition = -1;
    int m_matchedBracket1 = -1;
    int m_matchedBracket2 = -1;

    void updateBracketMatching();
    int findMatchingBracket(const QString &text, int index, QChar openChar, QChar closeChar, bool forward);
};
