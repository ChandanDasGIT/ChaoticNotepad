#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
class QQmlEngine;
class QJSEngine;
#include "wrapper/editor/editorrowsmodel.h"
#include "wrapper/editor/rowbuilder.h"
#include "textengine/inputHandler/inputhandler.h"
#include "textengine/stickyscroll/stickyscroll.h"
#include "textengine/tabs/tabmanager.h"

// The one object QML talks to for the editor (EditorController in QML).
// It owns the tabs and the engine's input state, turns Qt key and mouse events into engine events,
// carries out what the engine asks for (save, open, clipboard, tabs) and keeps the rows model up to date.
class EditorController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(EditorRowsModel* rows READ rows CONSTANT)
    Q_PROPERTY(QVariantList sticky READ sticky NOTIFY stickyChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY documentChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY documentChanged)

public:

    // There is one EditorController. QML gets it through create(); the gutter wrapper gets it through instance().
    static EditorController* instance();
    static EditorController* create(QQmlEngine*, QJSEngine*);

    // What the gutter wrapper reads
    const RowBuilder& builder() const { return m_builder; }
    const EditorTab& currentTab() const { return m_tabs.current(); }
    const QVariantList& stickyList() const { return m_sticky; }

    EditorRowsModel* rows() { return &m_rows; }
    QVariantList sticky() const { return m_sticky; }
    QString status() const { return m_status; }
    bool canUndo() const { return m_tabs.current().view.canUndo(); }
    bool canRedo() const { return m_tabs.current().view.canRedo(); }

    // What the other controllers (find, dialogs, tabs, status bar) use. They are not for QML.
    InputState& inputState() { return m_state; }
    TabManager& tabs() { return m_tabs; }
    EditorTab& tab() { return m_tabs.current(); }
    size_t firstRow() const { return m_firstRow; }       // the first row on screen
    size_t viewRows() const { return m_viewRows; }       // how many rows fit
    void scrollToRow(size_t row);                        // scroll the text area so this row is the first on screen
    void changedOutside(bool reveal);   // call after changing the engine from outside: works the rows out again and tells everyone

    // ---- commands from the toolbar ----
    Q_INVOKABLE void save();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    // For the other controllers (not for QML)
    void sendChar(char letter, bool ctrl, bool shift, bool alt);   // a command key such as Ctrl+O
    void send(const Input::Event& ev);                             // any engine event
    std::string saveTab(EditorTab& tab);                           // saves one tab and returns the message

    // ---- called by the text area ----
    Q_INVOKABLE void viewportChanged(int columns, int visibleRows, int firstRow);
    Q_INVOKABLE bool keyPressed(int key, const QString& text, int modifiers);   // true = the engine used the key
    Q_INVOKABLE void mousePress(int row, int cell, int button, int modifiers, int clicks);
    Q_INVOKABLE void mouseDrag(int row, int cell);
    Q_INVOKABLE void mouseRelease();
    Q_INVOKABLE void stickyClicked(int index);     // index of the pinned line, 0 = the first (also called by GutterController)
    void toggleFold(int row);                      // the fold arrow in the gutter (called by GutterController)

    // ---- files dropped on the window ----
    Q_INVOKABLE void openUrls(const QList<QUrl>& urls);

signals:
    void rowsRebuilt();                 // the rows were worked out again (the gutter refreshes itself on this)
    void stickyChanged();
    void statusChanged();
    void scrollRequested(int topRow);   // the text area should scroll so this row is the first on screen
    void viewChanged();                 // the scroll position or the pinned lines changed
    void documentChanged();             // tabs, titles or the saved state changed (for the tab bar and status bar)

private:
    // Private on purpose: there is exactly one, made by instance(). QML gets it through create().
    // (With a public constructor Qt may build a second one, and then QML and the wrappers talk to different objects.)
    explicit EditorController(QObject* parent = nullptr);

    void feed(const Input::Event& ev, bool reveal);
    void carryOut(std::vector<Request>& requests);
    void rebuild(bool force);
    void updateSticky();
    void revealCursor();
    void setStatus(const std::string& s);
    void saveCurrent();
    void saveCurrentAs(const std::string& path);
    void applyAppCommand(const Request& r);
    static Input::Mods toMods(int modifiers);

    TabManager m_tabs;
    InputState m_state;
    RowBuilder m_builder;
    StickyScroll m_stickyScroll;
    EditorRowsModel m_rows;

    size_t m_columns = 0;
    size_t m_viewRows = 20;
    size_t m_firstRow = 0;

    int m_lastTabId = -1;
    unsigned long long m_lastRevision = 0;
    size_t m_lastColumns = 0;
    bool m_built = false;

    std::vector<StickyRow> m_stickyRows;
    QVariantList m_sticky;
    QString m_status;
    bool m_quitArmed = false;
};
