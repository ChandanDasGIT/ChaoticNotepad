#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// What BottomStatusbar.qml shows (StatusController in QML). It only reads: nothing here changes the engine.
class StatusController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(int line READ line NOTIFY changed)
    Q_PROPERTY(int column READ column NOTIFY changed)
    Q_PROPERTY(int selectedChars READ selectedChars NOTIFY changed)
    Q_PROPERTY(int cursorCount READ cursorCount NOTIFY changed)
    Q_PROPERTY(QString indent READ indent NOTIFY changed)
    Q_PROPERTY(QString encoding READ encoding NOTIFY changed)
    Q_PROPERTY(QString lineEnding READ lineEnding NOTIFY changed)
    Q_PROPERTY(QString language READ language NOTIFY changed)
    Q_PROPERTY(int lines READ lines NOTIFY changed)
    Q_PROPERTY(int words READ words NOTIFY changed)
    Q_PROPERTY(int paragraphs READ paragraphs NOTIFY changed)

public:
    explicit StatusController(QObject* parent = nullptr);

    QString message() const { return m_message; }
    int line() const { return m_line; }
    int column() const { return m_column; }
    int selectedChars() const { return m_selectedChars; }
    int cursorCount() const { return m_cursorCount; }
    QString indent() const { return m_indent; }
    QString encoding() const { return m_encoding; }
    QString lineEnding() const { return m_lineEnding; }
    QString language() const { return m_language; }
    int lines() const { return m_lines; }
    int words() const { return m_words; }
    int paragraphs() const { return m_paragraphs; }

signals:
    void changed();

private:
    void sync();

    QString m_message = QStringLiteral("ready");
    int m_line = 1;
    int m_column = 1;
    int m_selectedChars = 0;
    int m_cursorCount = 1;
    QString m_indent, m_encoding, m_lineEnding, m_language;
    int m_lines = 1;
    int m_words = 0;
    int m_paragraphs = 0;
    int m_cachedWords = 0;                      // the counts of the text as it was at m_countRev
    int m_cachedParagraphs = 0;
    int m_countTab = -1;
    unsigned long long m_countRev = 0;
};
