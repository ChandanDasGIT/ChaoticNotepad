#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCommandLineParser>
#include <QFileInfo>
#include <QIcon>
#include "fileio.h"
#include "functions/highlighter/cpphighlighter.h"
#include "functions/textsercher/textsearcher.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    app.setOrganizationName("ChaoticNotepad");
    app.setOrganizationDomain("ChaoticNotepad.org");
    app.setApplicationName("ChaoticNotepad");

    // 1. Parse command line arguments
    QCommandLineParser parser;
    parser.setApplicationDescription("ChaoticNotepad Text Editor");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("file", "File to open");
    parser.process(app);

    // 2. Extract initial file path if provided
    QString initialFilePath = "";
    const QStringList posArgs = parser.positionalArguments();
    if (!posArgs.isEmpty()) {
        QFileInfo fileInfo(posArgs.first());
        if (fileInfo.exists()) {
            initialFilePath = fileInfo.absoluteFilePath();
        }
    }

    QQmlApplicationEngine engine;

    // 3. Expose the file path directly to the QML root context
    engine.rootContext()->setContextProperty("initialFileToOpen", initialFilePath);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    // 4. Load the module using the standard 2-argument overload
    engine.loadFromModule("NotepadQtQuick", "Main");

    return app.exec();
}
