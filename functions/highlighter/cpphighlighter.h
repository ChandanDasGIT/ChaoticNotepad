#pragma once

#include <QSyntaxHighlighter>
#include <QRegularExpression>
#include <QTextCharFormat>
#include <QQuickTextDocument>
#include <QColor>
#include <QString>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class CppHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString highlightedWord READ highlightedWord WRITE setHighlightedWord NOTIFY highlightedWordChanged)
    Q_PROPERTY(int cursorPosition READ cursorPosition WRITE setCursorPosition NOTIFY cursorPositionChanged)
    Q_PROPERTY(QString filePath READ filePath WRITE setFilePath NOTIFY filePathChanged)

public:
    explicit CppHighlighter(QObject *parent = nullptr);

    Q_INVOKABLE void setDocument(QQuickTextDocument *quickDocument);
    Q_INVOKABLE void clearBracketMatches();

    QString highlightedWord() const;
    void setHighlightedWord(const QString &word);

    int cursorPosition() const;
    void setCursorPosition(int pos);

    QString filePath() const;
    void setFilePath(const QString &path);

signals:
    void highlightedWordChanged();
    void cursorPositionChanged();
    void filePathChanged();

protected:
    void highlightBlock(const QString &text) override;

private:
    enum class Language { Cpp, Lua, Fish };

    struct HighlightingRule {
        QRegularExpression pattern;
        QTextCharFormat format;
    };
    QVector<HighlightingRule> m_highlightingRules;

    // Comment tokens (set per language in applyLanguage()).
    // An empty block token means the language has no block comments.
    QString m_lineCommentToken;
    QString m_blockStartToken;
    QString m_blockEndToken;

    QTextCharFormat m_keywordFormat;
    QTextCharFormat m_classFormat;
    QTextCharFormat m_singleLineCommentFormat;
    QTextCharFormat m_multiLineCommentFormat;
    QTextCharFormat m_quotationFormat;
    QTextCharFormat m_functionFormat;
    QTextCharFormat m_numberFormat;
    QTextCharFormat m_preprocessorFormat;

    Language m_language = Language::Cpp;
    QString m_filePath;

    QString m_highlightedWord;
    int m_cursorPosition = -1;
    int m_matchedBracket1 = -1;
    int m_matchedBracket2 = -1;

    void applyLanguage();
    void applyCommentFormats(const QString &text);
    void updateBracketMatching();
    int findMatchingBracket(const QString &text, int index, QChar openChar, QChar closeChar, bool forward);
};
