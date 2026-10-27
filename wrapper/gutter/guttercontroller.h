#pragma once
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include "wrapper/gutter/guttermodel.h"

// What Gutter.qml talks to (GutterController in QML). It owns nothing of the editor: it reads the rows
// from EditorController and passes clicks back to it.
class GutterController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(GutterModel* rows READ rows CONSTANT)
    Q_PROPERTY(int gutterDigits READ gutterDigits NOTIFY gutterDigitsChanged)
    Q_PROPERTY(QVariantList sticky READ sticky NOTIFY stickyChanged)   // the pinned lines: only their line numbers

public:
    explicit GutterController(QObject* parent = nullptr);

    GutterModel* rows() { return &m_rows; }
    int gutterDigits() const { return m_digits; }
    QVariantList sticky() const { return m_sticky; }

    Q_INVOKABLE void toggleFold(int row);        // the fold arrow of a row
    Q_INVOKABLE void stickyClicked(int index);   // a pinned line

signals:
    void gutterDigitsChanged();
    void stickyChanged();

private:
    void refresh();
    void refreshSticky();

    GutterModel m_rows;
    QVariantList m_sticky;
    int m_digits = 0;
};
