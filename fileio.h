#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QHash>
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

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            return false;
        }

        QTextStream out(&file);
        out << content;
        out.flush();
        file.close();

        // Remember what we wrote so the watcher can recognise its own save
        m_lastWritten.insert(filePath, content);

        // Ensure this file continues to be tracked
        watchFileInternal(filePath);

        return true;
    }

    Q_INVOKABLE void unwatchFile(const QString &filePath) {
        if (filePath.isEmpty()) return;
        if (m_watcher->files().contains(filePath)) {
            m_watcher->removePath(filePath);
        }
        m_lastWritten.remove(filePath);
    }

signals:
    void externalFileModified(const QString &filePath);

private slots:
    void onFileChanged(const QString &path) {
        // Some editors save via temporary file swap; re-attach watcher if needed
        if (QFile::exists(path) && !m_watcher->files().contains(path)) {
            m_watcher->addPath(path);
        }

        // Ignore the change event caused by our own writeFile()
        auto it = m_lastWritten.constFind(path);
        if (it != m_lastWritten.constEnd()) {
            QFile f(path);
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&f);
                if (in.readAll() == it.value()) return;
            }
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
    QHash<QString, QString> m_lastWritten;
};
