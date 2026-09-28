#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QSet>
#include <QtQml/qqmlregistration.h>

class FileIO : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit FileIO(QObject *parent = nullptr)
        : QObject(parent), m_watcher(new QFileSystemWatcher(this))
    {
        connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &FileIO::onFileChanged);
    }

    Q_INVOKABLE QString readFile(const QString &filePath) {
        if (filePath.isEmpty()) return QString();

        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return QString();
        }

        QTextStream in(&file);
        QString content = in.readAll();
        file.close();

        // Automatically watch any file successfully opened and read
        watchFileInternal(filePath);

        return content;
    }

    Q_INVOKABLE bool writeFile(const QString &filePath, const QString &content) {
        if (filePath.isEmpty()) return false;

        // Temporarily pause watcher to prevent our own write from triggering reload prompts
        m_suppressedFiles.insert(filePath);

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            m_suppressedFiles.remove(filePath);
            return false;
        }

        QTextStream out(&file);
        out << content;
        file.close();

        // Ensure this file continues to be tracked
        watchFileInternal(filePath);

        m_suppressedFiles.remove(filePath);
        return true;
    }

    Q_INVOKABLE void unwatchFile(const QString &filePath) {
        if (filePath.isEmpty()) return;
        if (m_watcher->files().contains(filePath)) {
            m_watcher->removePath(filePath);
        }
    }

signals:
    void externalFileModified(const QString &filePath);

private slots:
    void onFileChanged(const QString &path) {
        if (m_suppressedFiles.contains(path)) return;

        // Some editors save via temporary file swap; re-attach watcher if needed
        if (QFile::exists(path) && !m_watcher->files().contains(path)) {
            m_watcher->addPath(path);
        }

        emit externalFileModified(path);
    }

private:
    void watchFileInternal(const QString &filePath) {
        if (filePath.isEmpty() || !QFile::exists(filePath)) return;
        if (!m_watcher->files().contains(filePath)) {
            m_watcher->addPath(filePath);
        }
    }

    QFileSystemWatcher *m_watcher;
    QSet<QString> m_suppressedFiles;
};