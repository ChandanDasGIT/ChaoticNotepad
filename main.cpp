#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFileInfo>
#include <QList>
#include <QUrl>
#include "wrapper/editor/editorcontroller.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ChaoticNotepad", "Main");

    // files named on the command line open in tabs: appChaoticNotepad a.txt "my notes.md"
    QList<QUrl> urls;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args.at(i).startsWith(QLatin1Char('-'))) continue;                   // an option, not a file
        urls << QUrl::fromLocalFile(QFileInfo(args.at(i)).absoluteFilePath());    // relative names count from the current folder
    }
    if (!urls.isEmpty()) EditorController::instance()->openUrls(urls);

    return QGuiApplication::exec();
}
