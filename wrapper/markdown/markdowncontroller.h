#pragma once
#include <QObject>
#include <QString>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Manages the Markdown preview.
// QML accesses it as the singleton "MarkdownController".
//
// Two preview modes:
//   previewOpen  — full toggle (editor is hidden, preview takes the whole area)
//   splitOpen    — side-by-side (editor on left, preview on right)
//
// When the active file is not Markdown, both modes are closed automatically.
class MarkdownController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool isMarkdown  READ isMarkdown  NOTIFY stateChanged)
    Q_PROPERTY(bool previewOpen READ previewOpen NOTIFY stateChanged)
    Q_PROPERTY(bool splitOpen   READ splitOpen   NOTIFY stateChanged)
    Q_PROPERTY(QUrl baseUrl READ baseUrl NOTIFY htmlChanged)
    Q_PROPERTY(QString html     READ html        NOTIFY htmlChanged)

public:
    static MarkdownController* instance();
    static MarkdownController* create(QQmlEngine*, QJSEngine*);

    bool isMarkdown()  const;
    bool previewOpen() const { return m_previewOpen; }
    bool splitOpen()   const { return m_splitOpen; }
    QUrl baseUrl() const;
    QString html()     const { return m_html; }

    // Called by EditorController::keyPressed for Ctrl+Shift+V
    Q_INVOKABLE void toggleFullPreview();

    // Called for the Ctrl+Alt+V split shortcut (and toolbar button)
    Q_INVOKABLE void toggleSplitPreview();

signals:
    void stateChanged();
    void htmlChanged();

private:
    explicit MarkdownController(QObject* parent = nullptr);

    void onDocumentChanged();   // connected to EditorController::documentChanged
    void onThemeChanged();      // connected to SettingsController::changed
    void rebuild();             // re-render HTML from the current buffer
    void closeIfNotMarkdown();  // close both preview modes when file type changes

    bool m_previewOpen = false;
    bool m_splitOpen   = false;
    QString m_html;
};
