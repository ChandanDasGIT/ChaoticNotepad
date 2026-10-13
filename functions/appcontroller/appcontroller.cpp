#include "appcontroller.h"
#include <QFileInfo>
#include <QUrl>

AppController::AppController(QObject *parent)
: QObject(parent)
{
}

void AppController::setErrorText(const QString &msg)
{
    if (m_errorText == msg)
        return;
    m_errorText = msg;
    emit errorTextChanged();
}

void AppController::setPendingOverwritePath(const QString &path)
{
    if (m_pendingOverwritePath == path)
        return;
    m_pendingOverwritePath = path;
    emit pendingOverwritePathChanged();
}

void AppController::setTabPendingClose(int index)
{
    if (m_tabPendingClose == index)
        return;
    m_tabPendingClose = index;
    emit tabPendingCloseChanged();
}

void AppController::setIsClosingWindow(bool closing)
{
    if (m_isClosingWindow == closing)
        return;
    m_isClosingWindow = closing;
    emit isClosingWindowChanged();
}

QString AppController::prepareTextForSave(const QString &rawText) const
{
    if (rawText.isEmpty())
        return QString();
    if (rawText.endsWith(QLatin1Char('\n')))
        return rawText;
    return rawText + QLatin1Char('\n');
}

QString AppController::fileNameFromPath(const QString &filePath) const
{
    if (filePath.isEmpty())
        return QStringLiteral("untitled");
    return QFileInfo(filePath).fileName();
}

int AppController::findTabByPath(const QStringList &tabPaths, const QString &targetPath) const
{
    if (targetPath.isEmpty())
        return -1;

    const QString canonicalTarget = QFileInfo(targetPath).canonicalFilePath();
    const QString resolvedTarget = canonicalTarget.isEmpty() ? targetPath : canonicalTarget;

    for (int i = 0; i < tabPaths.size(); ++i) {
        const QString &fp = tabPaths.at(i);
        if (fp.isEmpty())
            continue;
        const QString c = QFileInfo(fp).canonicalFilePath();
        const QString resolved = c.isEmpty() ? fp : c;
        if (resolved == resolvedTarget)
            return i;
    }
    return -1;
}

QStringList AppController::collectSessionFiles(const QStringList &tabPaths) const
{
    QStringList result;
    for (const QString &fp : tabPaths) {
        if (!fp.isEmpty() && QFileInfo::exists(fp)) {
            result.append(fp);
        }
    }
    return result;
}

void AppController::resetPendingClose()
{
    setTabPendingClose(-1);
    setIsClosingWindow(false);
}
