#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QtQml/qqmlregistration.h>

class TextSearcher : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit TextSearcher(QObject *parent = nullptr);

    // Added wholeWord parameter (defaults to true)
    Q_INVOKABLE QList<int> findAll(const QString &text, const QString &query, bool caseSensitive = false, bool wholeWord = true);

    Q_INVOKABLE int findNext(int currentIndex, int matchCount);
    Q_INVOKABLE int findPrev(int currentIndex, int matchCount);

    Q_INVOKABLE QString replaceSingle(const QString &text, int startIndex, int queryLength, const QString &replacement);

    // Added wholeWord parameter (defaults to true)
    Q_INVOKABLE QString replaceAll(const QString &text, const QString &query, const QString &replacement, bool caseSensitive = false, bool wholeWord = true);
};