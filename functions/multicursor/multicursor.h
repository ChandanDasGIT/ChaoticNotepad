#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QString>
#include <QTextCursor>
#include <QTextDocument>
#include <QVariantList>
#include <QVector>
#include <QtQml/qqmlregistration.h>
#include <functional>

// Keeps a set of extra carets (the editor's own caret stays the "primary" one)
// and applies edits at all of them in a single undo step.
class MultiCursor : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList positions READ positions NOTIFY positionsChanged)
    Q_PROPERTY(bool active READ active NOTIFY positionsChanged)

public:
    explicit MultiCursor(QObject *parent = nullptr);

    Q_INVOKABLE void setDocument(QQuickTextDocument *quickDocument);

    QVariantList positions() const;
    bool active() const { return !m_cursors.isEmpty(); }

    Q_INVOKABLE void addCursor(int position);
    Q_INVOKABLE void clear();
    // Drops extra carets that landed on the primary caret
    Q_INVOKABLE void mergeWith(int primaryPosition);
    // direction: "left", "right", "up", "down", "home", "end" (moves the extra carets only)
    Q_INVOKABLE void move(const QString &direction, bool byWord);

    // Edits: applied at the primary caret + all extra carets.
    // Each returns the new position of the primary caret.
    Q_INVOKABLE int insertText(const QString &text, int primaryPosition);
    Q_INVOKABLE int insertNewline(int primaryPosition);
    Q_INVOKABLE int deleteBackward(int primaryPosition);
    Q_INVOKABLE int deleteForward(int primaryPosition);

signals:
    void positionsChanged();

private slots:
    void onContentsChange(int position, int removed, int added);

private:
    int apply(int primaryPosition, const std::function<void(QTextCursor &)> &op);
    QTextCursor makePrimary(int position);
    void prune(int primaryPosition);
    void emitIfChanged();

    QPointer<QTextDocument> m_doc;
    QVector<QTextCursor> m_cursors;
    QVariantList m_lastPositions;
    bool m_applying = false;
};
