#include "wrapper/update/updatecontroller.h"
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVersionNumber>
#include "third_party/monocypher/monocypher-ed25519.h"
#include "wrapper/dialog/dialogcontroller.h"
#include "wrapper/editor/editorcontroller.h"

// The test build replaces these three, to talk to a local server with a test key.
#ifndef UPDATE_API_URL
#define UPDATE_API_URL "https://api.github.com/repos/ChandanDasGIT/ChaoticNotepad"
#endif
#ifndef UPDATE_SITE_URL
#define UPDATE_SITE_URL "https://github.com/ChandanDasGIT/ChaoticNotepad"
#endif
#ifndef UPDATE_PUBLIC_KEY
#define UPDATE_PUBLIC_KEY "08b22dbf2cb4e6435e867e46ed61f2739a37b497d3915aea86f86177be459515"
#endif

namespace {
const qint64 kCheckEverySeconds = 24 * 60 * 60;
const char kStartedVariable[] = "CHAOTICNOTEPAD_UPDATE_STARTED";     // the file the new version creates when it runs

QSettings& file() {
    static QSettings s(QStringLiteral("ChaoticNotepad"), QStringLiteral("ChaoticNotepad"));
    return s;
}

bool isNewer(const QString& version) {
    return QVersionNumber::fromString(version) > QVersionNumber::fromString(QCoreApplication::applicationVersion());
}

// Programs started from here must not get the packaged app's library paths: they are for the app alone.
QProcessEnvironment cleanEnvironment() {
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    for (const char* name : {"LD_LIBRARY_PATH", "QT_PLUGIN_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH",
                             "APPDIR", "APPIMAGE", "ARGV0", "OWD"})
        env.remove(QString::fromLatin1(name));
    return env;
}

bool signatureIsValid(const QByteArray& message, const QByteArray& signature) {
    const QByteArray key = QByteArray::fromHex(UPDATE_PUBLIC_KEY);
    if (key.size() != 32 || signature.size() != 64) return false;
    return crypto_ed25519_check(reinterpret_cast<const uint8_t*>(signature.constData()),
                                reinterpret_cast<const uint8_t*>(key.constData()),
                                reinterpret_cast<const uint8_t*>(message.constData()),
                                static_cast<size_t>(message.size())) == 0;
}

// Runs after the program has quit.  $1 its pid   $2 the new copy   $3 the installed copy   $4 what to start
// $5 the update's folder   the rest: the files to open again.
const char kInstallScript[] = R"(#!/bin/sh
old_pid=$1; new=$2; installed=$3; program=$4; stage=$5
shift 5

i=0
while kill -0 "$old_pid" 2>/dev/null && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done

backup="$stage/previous"
if ! mv "$installed" "$backup"; then exec "$program" "$@"; fi
if ! mv "$new" "$installed"; then
    mv "$backup" "$installed"
    exec "$program" "$@"
fi

started="$stage/started"
exited="$stage/exited"
(
    CHAOTICNOTEPAD_UPDATE_STARTED="$started" "$program" "$@"
    touch "$exited" 2>/dev/null
) &
i=0
while [ ! -e "$started" ] && [ ! -e "$exited" ] && [ $i -lt 300 ]; do sleep 0.1; i=$((i + 1)); done

if [ ! -e "$started" ] && [ -e "$exited" ]; then                # it did not start: the old version comes back
    rm -rf "$installed"
    mv "$backup" "$installed"
    touch "$stage.failed"
    "$program" "$@" &
fi
rm -rf "$stage"
)";
}

UpdateController::UpdateController(QObject* parent) : QObject(parent) {
    QSettings& s = file();
    m_autoCheck = s.value("checkForUpdates", true).toBool();
    m_latest = s.value("latestVersion").toString();

    const QString appImage = qEnvironmentVariable("APPIMAGE");
    const QString data = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    const QString installed = data + QStringLiteral("/ChaoticNotepad");
    const QString here = QFileInfo(QCoreApplication::applicationDirPath()).canonicalFilePath();
    if (!appImage.isEmpty() && QFileInfo(QFileInfo(appImage).path()).isWritable()) {
        m_kind = Kind::AppImage;
        m_installed = appImage;
        m_program = appImage;
    } else if (here == QFileInfo(installed + QStringLiteral("/usr/bin")).canonicalFilePath()
               && QFileInfo::exists(installed + QStringLiteral("/AppRun"))) {
        m_kind = Kind::Tarball;
        m_installed = installed;
        m_program = installed + QStringLiteral("/AppRun");
    }

    if (m_kind != Kind::Manual) {
        m_stage = m_installed + QStringLiteral(".update");
        if (QFile::remove(m_stage + QStringLiteral(".failed")))
            m_status = QStringLiteral("The update did not start, so the previous version was put back.");
        if (qEnvironmentVariableIsEmpty(kStartedVariable)) QDir(m_stage).removeRecursively();    // left by an unfinished update
    }

    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, &UpdateController::installOnQuit);
    connect(DialogController::instance(), &DialogController::quitCancelled, this, [this] { m_restartWanted = false; });

    const qint64 last = s.value("lastUpdateCheck", 0).toLongLong();
    if (m_autoCheck && QDateTime::currentSecsSinceEpoch() - last >= kCheckEverySeconds)
        QTimer::singleShot(3000, this, [this] { check(false); });
}

bool UpdateController::available() const { return !m_latest.isEmpty() && isNewer(m_latest); }

void UpdateController::setStatus(const QString& text) {
    m_status = text;
    emit changed();
}

void UpdateController::fail(const QString& text) {
    m_busy = false;
    m_ready = false;
    m_download.close();
    if (!m_stage.isEmpty()) QDir(m_stage).removeRecursively();
    setStatus(text);
}

void UpdateController::setAutoCheck(bool on) {
    if (on == m_autoCheck) return;
    m_autoCheck = on;
    file().setValue("checkForUpdates", on);
    file().sync();
    emit changed();
}

void UpdateController::openReleasePage() {
    QDesktopServices::openUrl(QUrl(QStringLiteral(UPDATE_SITE_URL "/releases/latest")));
}

QString UpdateController::releaseFileUrl(const QString& name) const {
    return QStringLiteral(UPDATE_SITE_URL "/releases/download/v%1/%2").arg(m_latest, name);
}

// ------------------------------------------------------------------ is there a new version?

void UpdateController::checkNow() {
    if (!m_busy) check(true);
}

void UpdateController::check(bool byHand) {
    if (m_busy) return;
    m_busy = true;
    if (byHand) setStatus(QStringLiteral("Checking for updates…"));

    QNetworkRequest request{QUrl(QStringLiteral(UPDATE_API_URL "/releases/latest"))};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ChaoticNotepad"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    QNetworkReply* reply = m_net.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, byHand] {
        reply->deleteLater();
        m_busy = false;
        const QString tag = QJsonDocument::fromJson(reply->readAll()).object().value("tag_name").toString();
        if (reply->error() != QNetworkReply::NoError || !tag.startsWith(QLatin1Char('v'))) {
            if (byHand) setStatus(QStringLiteral("Could not reach GitHub. Try again later."));
            else emit changed();
            return;                                                // quietly: being offline is normal
        }
        m_latest = tag.mid(1);
        QSettings& s = file();
        s.setValue("latestVersion", m_latest);
        s.setValue("lastUpdateCheck", QDateTime::currentSecsSinceEpoch());
        s.sync();
        if (available()) setStatus(QStringLiteral("Version %1 is available.").arg(m_latest));
        else if (byHand) setStatus(QStringLiteral("You have the latest version."));
        else emit changed();
    });
}

// ------------------------------------------------------------------ getting it

void UpdateController::updateNow() {
    if (m_busy) return;
    if (m_ready) { askToRestart(); return; }
    if (!available() || !canInstall()) return;

    QDir(m_stage).removeRecursively();
    if (!QDir().mkpath(m_stage)) { fail(QStringLiteral("Could not write the update next to the program.")); return; }
    m_busy = true;
    setStatus(QStringLiteral("Checking the update…"));
    downloadManifest();
}

// The manifest and its signature come first: nothing else is downloaded unless they are right.
void UpdateController::downloadManifest() {
    const auto get = [this](const QString& name) {
        QNetworkRequest request{QUrl(releaseFileUrl(name))};
        request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ChaoticNotepad"));
        return m_net.get(request);
    };
    QNetworkReply* manifest = get(QStringLiteral("update-manifest.txt"));
    connect(manifest, &QNetworkReply::finished, this, [this, manifest, get] {
        manifest->deleteLater();
        if (manifest->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("This version has no signed update yet. Try again later."));
            return;
        }
        m_manifest = manifest->readAll();
        QNetworkReply* signature = get(QStringLiteral("update-manifest.txt.sig"));
        connect(signature, &QNetworkReply::finished, this, [this, signature] {
            signature->deleteLater();
            if (signature->error() != QNetworkReply::NoError) {
                fail(QStringLiteral("This version has no signed update yet. Try again later."));
                return;
            }
            if (!signatureIsValid(m_manifest, signature->readAll())) {
                fail(QStringLiteral("The update's signature is wrong, so it was not installed."));
                return;
            }

            // version 2.4
            // tarball ChaoticNotepad-2.4-linux-x86_64.tar.xz <sha256>
            // appimage ChaoticNotepad-2.4-x86_64.AppImage <sha256>
            QString version;
            const QString wanted = m_kind == Kind::Tarball ? QStringLiteral("tarball") : QStringLiteral("appimage");
            m_fileName.clear();
            for (const QString& line : QString::fromUtf8(m_manifest).split(QLatin1Char('\n'))) {
                const QStringList parts = line.split(QLatin1Char(' '));
                if (parts.size() == 2 && parts[0] == QLatin1String("version")) version = parts[1];
                if (parts.size() == 3 && parts[0] == wanted) { m_fileName = parts[1]; m_fileHash = parts[2].toLatin1(); }
            }
            if (version != m_latest || !isNewer(version) || m_fileName.isEmpty() || m_fileName.contains(QLatin1Char('/'))) {
                fail(QStringLiteral("The update's details are wrong, so it was not installed."));
                return;
            }
            downloadFile();
        });
    });
}

void UpdateController::downloadFile() {
    m_download.close();
    m_download.setFileName(m_stage + QLatin1Char('/') + m_fileName);
    if (!m_download.open(QIODevice::WriteOnly)) { fail(QStringLiteral("Could not write the update next to the program.")); return; }

    QNetworkRequest request{QUrl(releaseFileUrl(m_fileName))};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ChaoticNotepad"));
    QNetworkReply* reply = m_net.get(request);
    connect(reply, &QNetworkReply::readyRead, this, [this, reply] { m_download.write(reply->readAll()); });
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 done, qint64 total) {
        if (total > 0) setStatus(QStringLiteral("Downloading… %1%").arg(done * 100 / total));
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_download.write(reply->readAll());
        m_download.close();
        if (reply->error() != QNetworkReply::NoError) { fail(QStringLiteral("The download failed. Try again later.")); return; }
        onFileDownloaded();
    });
}

void UpdateController::onFileDownloaded() {
    QFile done(m_download.fileName());
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!done.open(QIODevice::ReadOnly) || !hash.addData(&done) || hash.result().toHex() != m_fileHash) {
        fail(QStringLiteral("The download does not match its signature, so it was not installed."));
        return;
    }
    done.close();

    if (m_kind == Kind::AppImage) {
        m_newCopy = done.fileName();
        done.setPermissions(done.permissions() | QFile::ExeOwner | QFile::ExeGroup | QFile::ExeOther);
        m_busy = false;
        m_ready = true;
        askToRestart();
        return;
    }
    unpack();
}

void UpdateController::unpack() {
    setStatus(QStringLiteral("Unpacking…"));
    const QString folder = m_stage + QStringLiteral("/unpacked");
    QDir().mkpath(folder);
    auto* tar = new QProcess(this);
    tar->setProcessEnvironment(cleanEnvironment());
    connect(tar, &QProcess::finished, this, [this, tar, folder](int code, QProcess::ExitStatus status) {
        tar->deleteLater();
        QFile::remove(m_download.fileName());                      // the tarball is not needed any more
        const QStringList top = QDir(folder).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        m_newCopy = top.size() == 1 ? folder + QLatin1Char('/') + top[0] + QStringLiteral("/app") : QString();
        if (status != QProcess::NormalExit || code != 0 || m_newCopy.isEmpty() || !QFileInfo(m_newCopy + QStringLiteral("/AppRun")).isExecutable()) {
            fail(QStringLiteral("Could not unpack the update."));
            return;
        }
        m_busy = false;
        m_ready = true;
        askToRestart();
    });
    tar->start(QStringLiteral("tar"), {QStringLiteral("-xJf"), m_download.fileName(), QStringLiteral("-C"), folder});
}

// ------------------------------------------------------------------ putting it in place

void UpdateController::askToRestart() {
    setStatus(QStringLiteral("Version %1 is ready. Restart to finish.").arg(m_latest));
    m_restartWanted = true;
    DialogController::instance()->requestQuit();                   // asks about unsaved tabs; Cancel keeps everything as it is
}

void UpdateController::installOnQuit() {
    if (!m_restartWanted) return;
    m_restartWanted = false;

    const QString scriptPath = m_stage + QStringLiteral("/install.sh");
    QFile script(scriptPath);
    if (!script.open(QIODevice::WriteOnly)) return;
    script.write(kInstallScript);
    script.close();

    QStringList arguments = {scriptPath, QString::number(QCoreApplication::applicationPid()), m_newCopy, m_installed, m_program, m_stage};
    TabManager& tabs = EditorController::instance()->tabs();       // the same files open again
    for (size_t i = 0; i < tabs.count(); ++i)
        if (!tabs.at(i).doc.path().empty()) arguments << QString::fromStdString(tabs.at(i).doc.path());

    QProcess process;
    process.setProcessEnvironment(cleanEnvironment());
    process.setProgram(QStringLiteral("/bin/sh"));
    process.setArguments(arguments);
    process.setWorkingDirectory(QDir::homePath());
    process.startDetached();
}

void UpdateController::reportStarted() {
    const QString started = qEnvironmentVariable(kStartedVariable);
    if (started.isEmpty()) return;
    QFile mark(started);
    if (mark.open(QIODevice::WriteOnly)) mark.close();
}
