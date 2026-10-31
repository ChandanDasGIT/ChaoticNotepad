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
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVersionNumber>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
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
const int kFirstCheckDelayMs = 3000;
const int kCheckIntervalMs = 60 * 60 * 1000;
const int kNetworkTimeoutMs = 30000;
const qint64 kUnfinishedAfterSeconds = 10 * 60;                  // a script takes about a minute at most
const char kStartedVariable[] = "CHAOTICNOTEPAD_UPDATE_STARTED"; // the file the new version creates when it runs
const char kOldExitedFile[] = "/old-exited";                     // the old program is gone
const char kInstallingFile[] = "/installing";                    // this folder is in use: don't clean it up

QString& startedFile() { static QString path; return path; }
QString& appImagePath() { static QString path; return path; }
QString& appDirPath() { static QString path; return path; }
QString& oldExitedMark() { static QString path; return path; }
int instanceLock = -1;

QSettings& file() {
    static QSettings s(QStringLiteral("ChaoticNotepad"), QStringLiteral("ChaoticNotepad"));
    return s;
}

void leaveMark(const QString& path) {
    QFile mark(path);
    if (mark.open(QIODevice::WriteOnly)) mark.close();
}

// Every running copy of the app keeps this lock, so an update can tell when another window is open.
void holdInstanceLock() {
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/ChaoticNotepad");
    QDir().mkpath(folder);
    instanceLock = open(QFile::encodeName(folder + QStringLiteral("/instances.lock")).constData(), O_RDWR | O_CREAT | O_CLOEXEC, 0600);
    if (instanceLock >= 0) flock(instanceLock, LOCK_SH | LOCK_NB);
}

bool otherInstancesRunning() {
    if (instanceLock < 0) return false;
    if (flock(instanceLock, LOCK_EX | LOCK_NB) != 0) return true;   // someone else holds it too
    flock(instanceLock, LOCK_SH | LOCK_NB);
    return false;
}

const QString kOtherWindow = QStringLiteral("Another ChaoticNotepad window is open. Close it, then try again.");

bool isVersion(const QString& text) {
    static const QRegularExpression pattern(QStringLiteral("^\\d+(\\.\\d+)*$"));
    return pattern.match(text).hasMatch();
}

bool isNewer(const QString& version) {
    return isVersion(version) && QVersionNumber::fromString(version) > QVersionNumber::fromString(QCoreApplication::applicationVersion());
}

// Programs started from here must not get the packaged app's library paths: they are for the app alone.
QProcessEnvironment cleanEnvironment() {
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    for (const char* name : {"LD_LIBRARY_PATH", "QT_PLUGIN_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"})
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

// Runs after the program has quit.  $1 the update's folder   $2 the new copy   $3 the installed copy
// $4 what to start   the rest: the files to open again.
// The new version gets its own process group, so a stuck one can be stopped together with what it started
// (an AppImage is more than one process).
const char kInstallScript[] = R"SCRIPT(#!/bin/sh
stage=$1; new=$2; installed=$3; program=$4
shift 4

# the old program leaves this file as the last thing it does
i=0
while [ ! -e "$stage/old-exited" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done

backup="$stage/previous"
if ! mv "$installed" "$backup"; then
    : > "$stage.failed"
    rm -rf "$stage"
    exec "$program" "$@"
fi
if ! mv "$new" "$installed"; then
    mv "$backup" "$installed"
    : > "$stage.failed"
    rm -rf "$stage"
    exec "$program" "$@"
fi

started="$stage/started"
exited="$stage/exited"
(
    export CHAOTICNOTEPAD_UPDATE_STARTED="$started"
    if command -v setsid > /dev/null 2>&1; then
        setsid --wait sh -c 'echo $$ > "$0"; exec "$@"' "$stage/pid" "$program" "$@"
    else
        sh -c 'echo $$ > "$0"; exec "$@"' "$stage/pid" "$program" "$@"
    fi
    { : > "$exited"; } 2>/dev/null
) &

# one minute, for a slow disk: after that it counts as stuck
deadline=$(($(date +%s) + 60))
while [ ! -e "$started" ] && [ ! -e "$exited" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 0.1; done

if [ ! -e "$started" ]; then                                    # it did not start: the old version comes back
    if [ ! -e "$exited" ] && [ -s "$stage/pid" ]; then
        pid=$(cat "$stage/pid")
        kill -s TERM -- "-$pid" 2>/dev/null || kill -s TERM "$pid" 2>/dev/null
        sleep 2
        kill -s KILL -- "-$pid" 2>/dev/null || kill -s KILL "$pid" 2>/dev/null
    fi
    rm -rf "$installed"
    mv "$backup" "$installed"
    : > "$stage.failed"
    rm -rf "$stage"
    "$program" "$@" &
    exit 0
fi
rm -rf "$stage"
)SCRIPT";
}

void UpdateController::readEnvironment() {
    startedFile() = qEnvironmentVariable(kStartedVariable);
    appImagePath() = qEnvironmentVariable("APPIMAGE");
    appDirPath() = qEnvironmentVariable("APPDIR");
    for (const char* name : {kStartedVariable, "APPIMAGE", "APPDIR", "ARGV0", "OWD"}) qunsetenv(name);
}

UpdateController::UpdateController(QObject* parent) : QObject(parent) {
    QSettings& s = file();
    m_autoCheck = s.value("checkForUpdates", true).toBool();
    m_latest = s.value("latestVersion").toString();
    holdInstanceLock();

    // Another program's AppImage can leave its variables behind, so the path only counts if this program runs from it.
    const QString here = QFileInfo(QCoreApplication::applicationDirPath()).canonicalFilePath();
    const QString mounted = QFileInfo(appDirPath()).canonicalFilePath();     // empty if that folder is gone
    const QString data = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    const QString installed = data + QStringLiteral("/ChaoticNotepad");
    if (!appImagePath().isEmpty() && !mounted.isEmpty() && here.startsWith(mounted + QLatin1Char('/'))) {
        const QFileInfo image(appImagePath());
        if (image.isFile() && image.isWritable() && QFileInfo(image.path()).isWritable()) {
            m_kind = Kind::AppImage;
            m_installed = image.absoluteFilePath();
            m_program = m_installed;
        }
    } else if (here == QFileInfo(installed + QStringLiteral("/usr/bin")).canonicalFilePath()
               && QFileInfo::exists(installed + QStringLiteral("/AppRun"))
               && QFileInfo(installed).isWritable() && QFileInfo(data).isWritable()) {
        m_kind = Kind::Tarball;
        m_installed = installed;
        m_program = installed + QStringLiteral("/AppRun");
    }

    if (m_kind != Kind::Manual) {
        m_stage = m_installed + QStringLiteral(".update");
        if (QFile::remove(m_stage + QStringLiteral(".failed"))) {
            m_status = QStringLiteral("The update did not start, so the previous version was put back.");
            QTimer::singleShot(0, this, [this] {
                DialogController::instance()->showNotice("Update not installed",
                    {"The new version did not start, so the previous version was put back.", "",
                     "Your files are safe. You can try the update again later."});
            });
        }
        // left by an unfinished update, unless a script or another window is working in there right now
        if (!stageInUse() && !otherInstancesRunning()) QDir(m_stage).removeRecursively();
    }

    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, &UpdateController::installOnQuit);
    connect(DialogController::instance(), &DialogController::quitCancelled, this, [this] { m_restartWanted = false; });

    m_dailyCheck.setInterval(kCheckIntervalMs);
    connect(&m_dailyCheck, &QTimer::timeout, this, &UpdateController::considerChecking);
    m_dailyCheck.start();
    QTimer::singleShot(kFirstCheckDelayMs, this, &UpdateController::considerChecking);
}

bool UpdateController::stageInUse() const {
    const QFileInfo inUse(m_stage + QLatin1String(kInstallingFile));
    return inUse.exists() && inUse.lastModified().secsTo(QDateTime::currentDateTime()) < kUnfinishedAfterSeconds;
}

QNetworkReply* UpdateController::get(const QString& url) {
    QNetworkRequest request{QUrl(url)};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ChaoticNotepad"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setTransferTimeout(kNetworkTimeoutMs);
    return m_net.get(request);
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

void UpdateController::considerChecking() {
    if (!m_autoCheck) return;
    if (QDateTime::currentSecsSinceEpoch() - file().value("lastUpdateCheck", 0).toLongLong() >= kCheckEverySeconds) check(false);
}

void UpdateController::checkNow() {
    if (!m_busy) check(true);
}

void UpdateController::check(bool byHand) {
    if (m_busy) return;
    m_busy = true;
    if (byHand) setStatus(QStringLiteral("Checking for updates…"));

    QNetworkReply* reply = get(QStringLiteral(UPDATE_API_URL "/releases/latest"));
    connect(reply, &QNetworkReply::finished, this, [this, reply, byHand] {
        reply->deleteLater();
        m_busy = false;
        const QString tag = QJsonDocument::fromJson(reply->readAll()).object().value("tag_name").toString();
        if (reply->error() != QNetworkReply::NoError || !tag.startsWith(QLatin1Char('v')) || !isVersion(tag.mid(1))) {
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
    if (otherInstancesRunning()) { setStatus(kOtherWindow); return; }
    if (m_ready) { askToRestart(); return; }
    if (!available() || !canInstall()) return;
    if (stageInUse()) { setStatus(QStringLiteral("An update is still finishing. Try again in a minute.")); return; }

    QDir(m_stage).removeRecursively();
    if (!QDir().mkpath(m_stage)) { fail(QStringLiteral("Could not write the update next to the program.")); return; }
    m_busy = true;
    setStatus(QStringLiteral("Checking the update…"));
    downloadManifest();
}

// The manifest and its signature come first: nothing else is downloaded unless they are right.
void UpdateController::downloadManifest() {
    QNetworkReply* manifest = get(releaseFileUrl(QStringLiteral("update-manifest.txt")));
    connect(manifest, &QNetworkReply::finished, this, [this, manifest] {
        manifest->deleteLater();
        if (manifest->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("This version has no signed update yet. Try again later."));
            return;
        }
        m_manifest = manifest->readAll();
        QNetworkReply* signature = get(releaseFileUrl(QStringLiteral("update-manifest.txt.sig")));
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

            // ChaoticNotepad update manifest 1
            // version 2.4
            // tarball ChaoticNotepad-2.4-linux-x86_64.tar.xz <sha256>
            // appimage ChaoticNotepad-2.4-x86_64.AppImage <sha256>
            // Every line must be exactly this. The names can only be these, so the manifest cannot point elsewhere.
            const QStringList lines = QString::fromUtf8(m_manifest).trimmed().split(QLatin1Char('\n'));
            const auto words = [&lines](int i) { return lines[i].split(QLatin1Char(' ')); };
            static const QRegularExpression hash(QStringLiteral("^[0-9a-f]{64}$"));
            const bool shape = lines.size() == 4 && lines[0] == QLatin1String("ChaoticNotepad update manifest 1")
                               && words(1).size() == 2 && words(1)[0] == QLatin1String("version")
                               && words(2).size() == 3 && words(2)[0] == QLatin1String("tarball")
                               && words(3).size() == 3 && words(3)[0] == QLatin1String("appimage");
            const QString version = shape ? words(1)[1] : QString();
            const QStringList chosen = shape ? words(m_kind == Kind::Tarball ? 2 : 3) : QStringList();
            const QString expected = QStringLiteral("ChaoticNotepad-") + version
                                     + (m_kind == Kind::Tarball ? QStringLiteral("-linux-x86_64.tar.xz") : QStringLiteral("-x86_64.AppImage"));
            if (!shape || version != m_latest || !isNewer(version) || chosen[1] != expected || !hash.match(chosen[2]).hasMatch()) {
                fail(QStringLiteral("The update's details are wrong, so it was not installed."));
                return;
            }
            m_fileName = chosen[1];
            m_fileHash = chosen[2].toLatin1();
            downloadFile();
        });
    });
}

void UpdateController::downloadFile() {
    m_download.close();
    m_download.setFileName(m_stage + QLatin1Char('/') + m_fileName);
    if (!m_download.open(QIODevice::WriteOnly)) { fail(QStringLiteral("Could not write the update next to the program.")); return; }

    QNetworkReply* reply = get(releaseFileUrl(m_fileName));
    const auto save = [this, reply] {
        const QByteArray bytes = reply->readAll();
        if (m_download.write(bytes) != bytes.size()) reply->abort();      // the disk is full
    };
    connect(reply, &QNetworkReply::readyRead, this, save);
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 done, qint64 total) {
        if (total > 0) setStatus(QStringLiteral("Downloading… %1%").arg(done * 100 / total));
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, save] {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) save();
        const bool complete = reply->error() == QNetworkReply::NoError && m_download.flush();
        m_download.close();
        if (!complete) { fail(QStringLiteral("The download failed. Try again later.")); return; }
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
    if (otherInstancesRunning()) { setStatus(kOtherWindow); return; }             // one may have opened meanwhile
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
    leaveMark(m_stage + QLatin1String(kInstallingFile));
    oldExitedMark() = m_stage + QLatin1String(kOldExitedFile);

    QStringList arguments = {scriptPath, m_stage, m_newCopy, m_installed, m_program};
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
    if (!startedFile().isEmpty()) leaveMark(startedFile());
    startedFile().clear();
}

// A normal quit means it worked, even in its first two seconds. A crash never gets here.
void UpdateController::reportExited() {
    reportStarted();
    if (!oldExitedMark().isEmpty()) leaveMark(oldExitedMark());
}
