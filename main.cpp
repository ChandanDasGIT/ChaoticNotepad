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

    // 2. Collect every file argument (%F passes several; %U passes file:// URLs)
    QStringList initialFiles;
    const QStringList posArgs = parser.positionalArguments();
    for (const QString &arg : posArgs) {
        const QString local = arg.startsWith(QLatin1String("file:"))
        ? QUrl(arg).toLocalFile()
        : arg;
        const QFileInfo fileInfo(local);
        if (fileInfo.exists() && fileInfo.isFile()) {
            const QString abs = fileInfo.absoluteFilePath();
            if (!initialFiles.contains(abs))
                initialFiles << abs;
        }
    }

    QQmlApplicationEngine engine;

    // 3. Expose the file path directly to the QML root context
    engine.rootContext()->setContextProperty("initialFilesToOpen", initialFiles);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    // 4. Load the module using the standard 2-argument overload
    engine.loadFromModule("NotepadQtQuick", "Main");

    return app.exec();
}
