#include "lspclient.h"
#include <QCoreApplication>
#include <QDebug>

LspClient::LspClient(QObject *parent)
: QObject(parent), m_process(new QProcess(this))
{
    connect(m_process, &QProcess::readyReadStandardOutput, this, &LspClient::onReadyRead);
    connect(m_process, &QProcess::errorOccurred, this, [](QProcess::ProcessError error) {
        qWarning() << "[LSP Error]" << error;
    });
}

LspClient::~LspClient()
{
    stopServer();
}

void LspClient::setLanguageId(const QString &id)
{
    if (m_languageId != id) {
        m_languageId = id;
        emit languageIdChanged();
    }
}

void LspClient::stopServer()
{
    if (m_process && m_process->state() == QProcess::Running) {
        m_process->kill();
        m_process->waitForFinished(1000);
        qDebug() << "[LSP] Stopped server.";
    }
    m_readBuffer.clear();
    m_completions.clear();
    emit completionsChanged();
}

void LspClient::startServer(const QString &executablePath, const QString &langId)
{
    if (m_process->state() == QProcess::Running) {
        if (m_languageId == langId) return;
        stopServer();
    }

    m_languageId = langId;

    QString program = executablePath;
    QStringList arguments;

    if (executablePath == "qmlls") {
        arguments << "--stream";
    } else if (executablePath.contains(" ")) {
        QStringList parts = executablePath.split(" ", Qt::SkipEmptyParts);
        program = parts.first();
        arguments = parts.mid(1);
    }

    m_process->start(program, arguments);
    if (!m_process->waitForStarted(3000)) {
        qWarning() << "[LSP] Failed to start:" << program;
        return;
    }

    qDebug() << "[LSP] Server active:" << program << "for" << m_languageId;

    // Send Initialize Request
    QJsonObject capabilities;
    QJsonObject textDoc;
    textDoc["completion"] = QJsonObject{{"completionItem", QJsonObject{{"snippetSupport", false}}}};
    capabilities["textDocument"] = textDoc;

    QJsonObject params;
    params["processId"] = static_cast<int>(QCoreApplication::applicationPid());
    params["capabilities"] = capabilities;
    params["rootUri"] = QJsonValue::Null;

    QJsonObject request;
    request["jsonrpc"] = "2.0";
    request["id"] = m_requestId++;
    request["method"] = "initialize";
    request["params"] = params;

    sendPayload(request);
}

void LspClient::sendPayload(const QJsonObject &obj)
{
    if (!m_process || m_process->state() != QProcess::Running) return;
    QByteArray content = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    QByteArray header = QString("Content-Length: %1\r\n\r\n").arg(content.size()).toUtf8();
    m_process->write(header + content);
}

void LspClient::openDocument(const QString &fileUri, const QString &text)
{
    if (!m_process || m_process->state() != QProcess::Running) return;

    QJsonObject item;
    item["uri"] = fileUri;
    item["languageId"] = m_languageId;
    item["version"] = 1;
    item["text"] = text;

    QJsonObject notification;
    notification["jsonrpc"] = "2.0";
    notification["method"] = "textDocument/didOpen";
    notification["params"] = QJsonObject{{"textDocument", item}};

    sendPayload(notification);
}

void LspClient::updateDocument(const QString &fileUri, int version, const QString &text)
{
    if (!m_process || m_process->state() != QProcess::Running) return;

    QJsonObject change;
    change["text"] = text;

    QJsonArray changes;
    changes.append(change);

    QJsonObject doc;
    doc["uri"] = fileUri;
    doc["version"] = version;

    QJsonObject notification;
    notification["jsonrpc"] = "2.0";
    notification["method"] = "textDocument/didChange";
    notification["params"] = QJsonObject{
        {"textDocument", doc},
        {"contentChanges", changes}
    };

    sendPayload(notification);
}

void LspClient::requestCompletion(const QString &fileUri, int line, int character)
{
    if (!m_process || m_process->state() != QProcess::Running) return;

    m_lastCompletionId = m_requestId++;

    // Using Kate's LSPPosition
    LSPPosition position{line, character};

    QJsonObject posJson;
    posJson["line"] = position.line;
    posJson["character"] = position.column;

    QJsonObject request;
    request["jsonrpc"] = "2.0";
    request["id"] = m_lastCompletionId;
    request["method"] = "textDocument/completion";
    request["params"] = QJsonObject{
        {"textDocument", QJsonObject{{"uri", fileUri}}},
        {"position", posJson}
    };

    sendPayload(request);
}

void LspClient::onReadyRead()
{
    m_readBuffer.append(m_process->readAllStandardOutput());

    while (true) {
        int headerEnd = m_readBuffer.indexOf("\r\n\r\n");
        if (headerEnd == -1) break;

        QByteArray header = m_readBuffer.left(headerEnd);
        int length = 0;
        for (const QByteArray &line : header.split('\r')) {
            if (line.trimmed().startsWith("Content-Length:")) {
                length = line.split(':')[1].trimmed().toInt();
                break;
            }
        }

        int totalMsgLength = headerEnd + 4 + length;
        if (m_readBuffer.size() < totalMsgLength) break;

        QByteArray body = m_readBuffer.mid(headerEnd + 4, length);
        m_readBuffer.remove(0, totalMsgLength);

        QJsonDocument doc = QJsonDocument::fromJson(body);
        if (doc.isObject()) {
            handleMessage(doc.object());
        }
    }
}

void LspClient::handleMessage(const QJsonObject &obj)
{
    // Initialize handshake ack
    if (obj.contains("id") && obj["id"].toInt() == 1) {
        QJsonObject initializedNotif;
        initializedNotif["jsonrpc"] = "2.0";
        initializedNotif["method"] = "initialized";
        initializedNotif["params"] = QJsonObject();
        sendPayload(initializedNotif);
        qDebug() << "[LSP] Ready for" << m_languageId;
        return;
    }

    // Parse completions using Kate's protocol parser
    if (obj.contains("id") && obj["id"].toInt() == m_lastCompletionId) {
        m_completions.clear();

        QJsonValue resultVal = obj["result"];
        QList<LSPCompletionItem> items = parseDocumentCompletion(resultVal);

        for (const auto &item : items) {
            // Prefer insertText if specified, otherwise use label
            if (!item.insertText.isEmpty()) {
                m_completions.append(item.insertText);
            } else {
                m_completions.append(item.label);
            }
        }

        emit completionsChanged();
    }
}
