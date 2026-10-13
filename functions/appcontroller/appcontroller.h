#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QFileInfo>
#include <QtQml/qqmlregistration.h>

class AppController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString errorText READ errorText WRITE setErrorText NOTIFY errorTextChanged)
    Q_PROPERTY(QString pendingOverwritePath READ pendingOverwritePath WRITE setPendingOverwritePath NOTIFY pendingOverwritePathChanged)
    Q_PROPERTY(int tabPendingClose READ tabPendingClose WRITE setTabPendingClose NOTIFY tabPendingCloseChanged)
    Q_PROPERTY(bool isClosingWindow READ isClosingWindow WRITE setIsClosingWindow NOTIFY isClosingWindowChanged)

public:
    explicit AppController(QObject *parent = nullptr);

    QString errorText() const { return m_errorText; }
    void setErrorText(const QString &msg);

    QString pendingOverwritePath() const { return m_pendingOverwritePath; }
    void setPendingOverwritePath(const QString &path);

    int tabPendingClose() const { return m_tabPendingClose; }
    void setTabPendingClose(int index);

    bool isClosingWindow() const { return m_isClosingWindow; }
    void setIsClosingWindow(bool closing);

    // Formats text before saving (ensures single trailing newline if non-empty)
    Q_INVOKABLE QString prepareTextForSave(const QString &rawText) const;

    // Returns file base name (e.g., "/path/to/main.cpp" -> "main.cpp")
    Q_INVOKABLE QString fileNameFromPath(const QString &filePath) const;

    // Checks whether an existing tab already has this canonical path. Returns matching index or -1
    Q_INVOKABLE int findTabByPath(const QStringList &tabPaths, const QString &targetPath) const;

    // Extracts valid file paths for session persistence
    Q_INVOKABLE QStringList collectSessionFiles(const QStringList &tabPaths) const;

    // Resets half-finished close-and-save requests
    Q_INVOKABLE void resetPendingClose();

signals:
    void errorTextChanged();
    void pendingOverwritePathChanged();
    void tabPendingCloseChanged();
    void isClosingWindowChanged();

private:
    QString m_errorText;
    QString m_pendingOverwritePath;
    int m_tabPendingClose = -1;
    bool m_isClosingWindow = false;
};
