#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// What FindReplaceBar.qml talks to (FindController in QML). The search itself is done by the engine;
// this keeps the engine's find state (InputState + TextView) in step with the bar.
class FindController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool open READ isOpen NOTIFY openChanged)
    Q_PROPERTY(bool replaceOpen READ replaceOpen NOTIFY stateChanged)
    Q_PROPERTY(QString findText READ findText NOTIFY stateChanged)
    Q_PROPERTY(QString replaceText READ replaceText NOTIFY stateChanged)
    Q_PROPERTY(bool matchCase READ matchCase NOTIFY stateChanged)
    Q_PROPERTY(bool wholeWord READ wholeWord NOTIFY stateChanged)
    Q_PROPERTY(bool regex READ regex NOTIFY stateChanged)
    Q_PROPERTY(bool inSelection READ inSelection NOTIFY stateChanged)
    Q_PROPERTY(QString counter READ counter NOTIFY stateChanged)
    Q_PROPERTY(bool counterIsError READ counterIsError NOTIFY stateChanged)

public:
    explicit FindController(QObject* parent = nullptr);

    bool isOpen() const { return m_open; }
    bool replaceOpen() const { return m_replaceOpen; }
    QString findText() const { return m_findText; }
    QString replaceText() const { return m_replaceText; }
    bool matchCase() const { return m_case; }
    bool wholeWord() const { return m_word; }
    bool regex() const { return m_regex; }
    bool inSelection() const { return m_inSel; }
    QString counter() const { return m_counter; }
    bool counterIsError() const { return m_counterError; }

    Q_INVOKABLE void openFind();          // the Find button; Ctrl+F in the text does the same through the engine
    Q_INVOKABLE void openReplace();
    Q_INVOKABLE void toggleReplace();     // show or hide the replace row
    Q_INVOKABLE void close();

    Q_INVOKABLE void setFindText(const QString& text);
    Q_INVOKABLE void setReplaceText(const QString& text);
    Q_INVOKABLE void next();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void selectAll();         // a cursor on every match; closes the bar
    Q_INVOKABLE void replaceCurrent();
    Q_INVOKABLE void replaceAll();
    Q_INVOKABLE void toggleCase();
    Q_INVOKABLE void toggleWord();
    Q_INVOKABLE void toggleRegex();
    Q_INVOKABLE void toggleSelection();

signals:
    void openChanged();
    void stateChanged();
    void focusFind();                     // put the keyboard in the find field
    void focusReplace();

private:
    void openWith(bool withReplace);
    void search();                        // runs the engine's search with the current text and options
    void finish(bool reveal);             // tells the editor and syncs this object
    void sync();                          // copies the engine's find state into the properties

    bool m_open = false;
    bool m_replaceOpen = false;
    QString m_findText;
    QString m_replaceText;
    bool m_case = false;
    bool m_word = false;
    bool m_regex = false;
    bool m_inSel = false;
    QString m_counter;
    bool m_counterError = false;
};
