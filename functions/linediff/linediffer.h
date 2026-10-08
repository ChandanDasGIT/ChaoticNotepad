#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class LineDiffer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LineDiffer(QObject *parent = nullptr);

    // Compares `disk` with `current` line by line.
    // Returns one entry per line of `current`:
    //   0 = unchanged, 1 = modified, 2 = added
    Q_INVOKABLE QVariantList diff(const QString &disk, const QString &current) const;
};
