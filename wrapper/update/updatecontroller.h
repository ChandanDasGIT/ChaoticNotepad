#pragma once
#include <QByteArray>
#include <QCryptographicHash>
#include <QFile>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
#include <functional>

class QNetworkReply;

// New versions (UpdateController in QML). Once a day it asks GitHub for the latest release: a newer one shows
// the green dot in the bottom bar. The update itself only starts from the Update now button in the settings.
//
// How an update stays safe: every release has update-manifest.txt (version, file names and their SHA-256) and
// update-manifest.txt.sig, signed in the release workflow with the private key. The public key is built into
// the app, and nothing is installed unless the signature, the version and the file's hash are all right.
//
// A tarball install and an AppImage can update themselves. An install in /usr/local needs root, so it only
// gets the dot and a link to the release page.
//
// When the new files are ready the program quits (asking about unsaved tabs first) and a small script takes
// over: it swaps the files and starts the new version. If that exits, crashes or hangs before it really runs,
// the old one comes back and says so. While another window of the app is open, no update starts.
class UpdateController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY changed)           // a newer version exists: the green dot
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)              // the text in the About section
    Q_PROPERTY(bool busy READ busy NOTIFY changed)                     // checking or downloading
    Q_PROPERTY(bool canInstall READ canInstall CONSTANT)               // false: only the release page can help
    Q_PROPERTY(bool readyToRestart READ readyToRestart NOTIFY changed) // downloaded and checked
    Q_PROPERTY(bool autoCheck READ autoCheck NOTIFY changed)

public:
    explicit UpdateController(QObject* parent = nullptr);

    bool available() const;
    QString latestVersion() const { return m_latest; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }
    bool canInstall() const { return m_kind != Kind::Manual; }
    bool readyToRestart() const { return m_ready; }
    bool autoCheck() const { return m_autoCheck; }

    Q_INVOKABLE void setAutoCheck(bool on);
    Q_INVOKABLE void checkNow();
    Q_INVOKABLE void updateNow();
    Q_INVOKABLE void openReleasePage();

    static void readEnvironment();      // first thing in main: keeps the update's variables away from other programs
    static void reportStarted();        // the new version runs: the script then knows the update worked
    static void reportExited();         // last thing in main: the script may now swap the files

signals:
    void changed();

private:
    enum class Kind { Tarball, AppImage, Manual };

    void considerChecking();
    void check(bool byHand);
    void downloadManifest();
    void downloadFile();
    void onFileDownloaded();
    void unpack();
    void askToRestart();
    void installOnQuit();
    void fail(const QString& text);
    bool stageInUse() const;          // an update script is working in the update's folder
    QNetworkReply* get(const QString& url);
    void fetch(const QString& url, const std::function<void(QNetworkReply*)>& started);   // a release file: see the .cpp
    void pickAddress(const QUrl& url, const std::function<void(const QString&)>& picked);
    void setStatus(const QString& text);
    QString releaseFileUrl(const QString& name) const;

    QNetworkAccessManager m_net;
    Kind m_kind = Kind::Manual;
    QString m_latest;                 // the newest version known, without the v
    QString m_status;
    bool m_busy = false;
    bool m_ready = false;
    bool m_restartWanted = false;     // set only once the update's quit is going ahead
    bool m_autoCheck = true;

    QString m_installed;              // what the update replaces: the program's folder, or the AppImage
    QString m_stage;                  // the update's own folder next to it, so the swap is a plain rename
    QString m_newCopy;                // the new folder or AppImage, ready to take its place
    QString m_program;                // what to start afterwards
    QByteArray m_manifest;
    QString m_fileName;               // from the signed manifest
    QByteArray m_fileHash;
    QString m_goodHost;               // an address of this host answered: the next files use it too
    QString m_goodAddress;
    QFile m_download;
    QCryptographicHash m_hash{QCryptographicHash::Sha256};   // of the download, as it arrives: no pause at the end
    QTimer m_dailyCheck;              // an editor can stay open for days
};
