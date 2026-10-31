#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <vector>
#include "textengine/dialog/dialog.h"

class QQmlEngine;
class QJSEngine;

// The question box (PromptDialog.qml talks to DialogController). It holds the engine's Dialog and the
// questions the program asks: unsaved changes when closing a tab or quitting, a file that changed on disk,
// and a save that would overwrite someone else's changes.
class DialogController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QStringList lines READ lines NOTIFY changed)
    Q_PROPERTY(QStringList buttons READ buttons NOTIFY changed)
    Q_PROPERTY(int selectedButton READ selectedButton NOTIFY changed)

public:

    static DialogController* instance();
    static DialogController* create(QQmlEngine*, QJSEngine*);

    bool active() const { return m_dialog.active(); }
    QString title() const;
    QStringList lines() const;
    QStringList buttons() const;
    int selectedButton() const { return m_dialog.selectedButton(); }

    Q_INVOKABLE bool keyPressed(int key, const QString& text, int modifiers);
    Q_INVOKABLE void clickButton(int index);

    // The questions. The editor calls these.
    void requestClose(size_t tabIndex);                          // closes it, or asks first when it has unsaved changes
    void requestQuit(bool forUpdate = false);                    // quits, or asks about each unsaved tab first
    Q_INVOKABLE bool closeRequested();                           // the window was asked to close (X, Super+C): true = let it close, false = the unsaved changes box was shown
    void showSaveConflict(int tabId, const std::string& name);   // "the file changed on disk: overwrite?"
    void showNotice(const std::string& title, const std::vector<std::string>& lines);   // something to read, with an OK button

signals:
    void changed();
    void quittingForUpdate();          // every question was answered and the update's quit is going ahead

private:
    // Private on purpose: there is exactly one, made by instance(). QML gets it through create().
    // (With a public constructor Qt may build a second one, and then QML and the wrappers talk to different objects.)
    explicit DialogController(QObject* parent = nullptr);

    enum class For { CloseTab, Quit, DiskChanged, SaveConflict, Notice };

    void handle(Dialog::Result r);
    void onResult(Dialog::Result r);
    void advance();                    // finishes "save, then close" and goes on after a save while quitting
    void askNextBeforeQuit();          // shows the next unsaved tab and asks about it; no tab left: quits
    bool checkExternalChange();        // true if something visible happened
    void startSave(size_t tabIndex);
    size_t indexOfTab(int id) const;
    void quitApp();

    Dialog m_dialog;
    For m_for = For::CloseTab;
    int m_tabId = 0;                   // the tab the box is about
    int m_closeAfterSaveId = 0;        // close this tab as soon as its save has finished
    bool m_quitting = false;           // going through the unsaved tabs before quitting
    bool m_quitForUpdate = false;      // this quit was asked for by the update
    int m_quitSaveId = 0;              // quitting: the tab being saved now
    std::vector<int> m_quitSkipped;    // quitting: the tabs you answered "Don't save" for
    bool m_advancing = false;
    bool m_quitConfirmed = false;      // the program decided to quit: the window may close without asking again
    int m_quietTabId = 0;              // you cancelled a save over this file's outside change: no box until it changes again
    long long m_quietTime = 0;
    long long m_quietSize = 0;
    QTimer m_poll;                     // looks for changes made to the open file by other programs
};
