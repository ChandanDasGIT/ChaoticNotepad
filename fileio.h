#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QHash>
#include <QUrl>
#include <QVariantMap>
#include <QStringConverter>
#include <QtQml/qqmlregistration.h>
#include <QSaveFile>

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

    // Returns { ok: bool, text: string, error: string }.
    // A failed read is reported instead of returning "", so the caller never
    // mistakes a missing/unreadable file for an empty one.
    Q_INVOKABLE QVariantMap readFileResult(const QString &filePath) {
        QVariantMap result;
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("text"), QString());
        result.insert(QStringLiteral("lineEnding"), QStringLiteral("\n"));

        if (filePath.isEmpty()) {
            result.insert(QStringLiteral("error"), QStringLiteral("No file path given."));
            return result;
        }

        const QFileInfo info(filePath);
        if (!info.exists()) {
            result.insert(QStringLiteral("error"), QStringLiteral("File not found: %1").arg(filePath));
            return result;
        }
        if (!info.isFile()) {
            result.insert(QStringLiteral("error"), QStringLiteral("Not a regular file: %1").arg(filePath));
            return result;
        }

        constexpr qint64 kMaxFileBytes = 20 * 1024 * 1024;   // raise this if you like
        if (info.size() > kMaxFileBytes) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("%1 is larger than 20 MB; not opened.").arg(info.fileName()));
            return result;
        }

        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("Cannot open %1: %2").arg(filePath, file.errorString()));
            return result;
        }
        const QByteArray data = file.readAll();
        file.close();

        if (data.contains('\0')) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("%1 looks like a binary file; not opened.").arg(info.fileName()));
            return result;
        }

        // Strict UTF-8: refuse files that would be silently mangled on save
        QStringDecoder decoder(QStringConverter::Utf8, QStringConverter::Flag::Stateless);
        QString content = decoder(data);
        if (decoder.hasError()) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("%1 is not valid UTF-8 text; not opened to avoid corrupting it.")
                          .arg(info.fileName()));
            return result;
        }

        // Remember the file's line ending so save can restore it, then work in LF
        const bool usesCrlf = content.contains(QStringLiteral("\r\n"));
        content.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));

        watchFileInternal(filePath);

        result[QStringLiteral("ok")] = true;
        result[QStringLiteral("text")] = content;
        result[QStringLiteral("lineEnding")] = usesCrlf ? QStringLiteral("\r\n") : QStringLiteral("\n");
        return result;
    }

    // Kept for compatibility: empty string on failure. Prefer readFileResult().
    Q_INVOKABLE QString readFile(const QString &filePath) {
        return readFileResult(filePath).value(QStringLiteral("text")).toString();
    }

    Q_INVOKABLE bool writeFile(const QString &filePath, const QString &content,
                               const QString &lineEnding = QStringLiteral("\n")) {
        if (filePath.isEmpty()) return false;

        QString out = content;
        if (lineEnding == QStringLiteral("\r\n"))
            out.replace(QLatin1Char('\n'), QStringLiteral("\r\n"));

        // Written to a temp file first, then swapped in only if everything succeeded
        QSaveFile file(filePath);
        if (!file.open(QIODevice::WriteOnly)) return false;

        const QByteArray bytes = out.toUtf8();
        if (file.write(bytes) != bytes.size()) {
            file.cancelWriting();
            return false;
        }
        if (!file.commit()) return false;

        // Remember what we wrote so the watcher can recognise its own save
        m_lastWritten.insert(filePath, content);
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

    // "file:///home/me/my%20docs/a.txt" -> "/home/me/my docs/a.txt".
    // Plain paths are returned unchanged.
    Q_INVOKABLE QString toLocalPath(const QString &urlOrPath) const {
        if (urlOrPath.startsWith(QStringLiteral("file:")))
            return QUrl(urlOrPath).toLocalFile();
        return urlOrPath;
    }

    // True only for local file:// URLs that point at an existing regular file.
    // Used by drag and drop to ignore anything that isn't a real file.
    Q_INVOKABLE bool isOpenableDropUrl(const QUrl &url) const {
        if (!url.isLocalFile()) return false;
        return QFileInfo(url.toLocalFile()).isFile();
    }

    // Resolves symlinks and "..", so two spellings of one file compare equal.
    // Falls back to the given path if the file doesn't exist.
    Q_INVOKABLE QString canonicalPath(const QString &path) const {
        const QString c = QFileInfo(path).canonicalFilePath();
        return c.isEmpty() ? path : c;
    }

    Q_INVOKABLE QUrl toFileUrl(const QString &localPath) const {
        return QUrl::fromLocalFile(localPath);
    }

    Q_INVOKABLE bool fileExists(const QString &filePath) const {
        return QFileInfo::exists(filePath);
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
