#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// What FileBrowserDialog.qml talks to (BrowserController in QML). The engine's file browser lives in the
// engine's input state; this shows it to QML and passes the keys and clicks back.
class BrowserController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool open READ isOpen NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QString actionLabel READ actionLabel NOTIFY changed)
    Q_PROPERTY(QString shownDirectory READ shownDirectory NOTIFY changed)
    Q_PROPERTY(QString fieldLabel READ fieldLabel NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY changed)
    Q_PROPERTY(int selectedRow READ selectedRow NOTIFY changed)
    Q_PROPERTY(bool listHasFocus READ listHasFocus NOTIFY changed)
    Q_PROPERTY(bool showHidden READ showHidden NOTIFY changed)
    Q_PROPERTY(QString emptyMessage READ emptyMessage NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString hint READ hint NOTIFY changed)

public:
    explicit BrowserController(QObject* parent = nullptr);

    bool isOpen() const { return m_open; }
    QString title() const { return m_title; }
    QString actionLabel() const { return m_actionLabel; }
    QString shownDirectory() const { return m_directory; }
    QString fieldLabel() const { return m_fieldLabel; }
    QString name() const { return m_name; }
    QVariantList entries() const { return m_entries; }
    int selectedRow() const { return m_selected; }
    bool listHasFocus() const { return m_listFocus; }
    bool showHidden() const { return m_hidden; }
    QString emptyMessage() const { return m_empty; }
    QString error() const { return m_error; }
    QString hint() const { return m_hint; }

    Q_INVOKABLE void openFile();            // the Open button (Ctrl+O does the same)
    Q_INVOKABLE void saveFileAs();          // the Save As button (Alt+S does the same)
    Q_INVOKABLE void setVisibleRows(int rows);
    Q_INVOKABLE bool keyPressed(int key, const QString& text, int modifiers);
    Q_INVOKABLE void click(int row);
    Q_INVOKABLE void activate();            // the main button: same as Enter
    Q_INVOKABLE void cancel();              // same as Esc
    Q_INVOKABLE void goUp();
    Q_INVOKABLE void toggleHidden();

signals:
    void changed();

private:
    void sync();

    bool m_open = false;
    QString m_title, m_actionLabel, m_directory, m_fieldLabel, m_name, m_empty, m_error, m_hint;
    QVariantList m_entries;
    int m_selected = 0;
    bool m_listFocus = false;
    bool m_hidden = false;
    QString m_key;                          // what the entries were last built for
};
