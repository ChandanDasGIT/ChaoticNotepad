#pragma once

#include <QObject>
#include <QPointer>
#include <QList>
#include <QQuickTextDocument>
#include <QTextDocument>
#include <QtQml/qqmlregistration.h>
#include <QVariantList>

class StickyScroll : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit StickyScroll(QObject *parent = nullptr);

    Q_INVOKABLE void setDocument(QQuickTextDocument *doc);

    // Returns a list of maps containing "lineNum" and "text" for the active scopes
    Q_INVOKABLE QVariantList getStickyLinesForPosition(int pos);

private slots:
    void onContentsChange();

private:
    void recalculateScopes();

    QPointer<QTextDocument> m_doc;
    QList<int> m_scopeEnds;
    bool m_dirty = true;
};
