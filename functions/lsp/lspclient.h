#pragma once

#include <QObject>
#include <QProcess>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

#include "lspclientprotocol.h"

class LspClient : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList completions READ completions NOTIFY completionsChanged)
    Q_PROPERTY(QString languageId READ languageId WRITE setLanguageId NOTIFY languageIdChanged)

public:
    explicit LspClient(QObject *parent = nullptr);
    ~LspClient();

    Q_INVOKABLE void startServer(const QString &executablePath, const QString &langId = "qml");
    Q_INVOKABLE void stopServer();
    Q_INVOKABLE void openDocument(const QString &fileUri, const QString &text);
    Q_INVOKABLE void updateDocument(const QString &fileUri, int version, const QString &text);
    Q_INVOKABLE void requestCompletion(const QString &fileUri, int line, int character);

    QStringList completions() const { return m_completions; }
    QString languageId() const { return m_languageId; }
    void setLanguageId(const QString &id);

signals:
    void completionsChanged();
    void languageIdChanged();

private slots:
    void onReadyRead();

private:
    void sendPayload(const QJsonObject &obj);
    void handleMessage(const QJsonObject &obj);

    QProcess *m_process{nullptr};
    QByteArray m_readBuffer;
    int m_requestId{1};
    int m_lastCompletionId{-1};
    QStringList m_completions;
    QString m_languageId{"qml"};
};
