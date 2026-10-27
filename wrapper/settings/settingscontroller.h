#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// What SettingsDialog.qml talks to (SettingsController in QML). The choices are remembered between runs
// (QSettings) and applied to the engine: indentation and bracket closing for every tab, the minimap switch.
// The font and the dark mode are applied by the dialog itself, which binds them to Theme.
class SettingsController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool darkTheme READ darkTheme NOTIFY changed)
    Q_PROPERTY(QString fontFamily READ fontFamily NOTIFY changed)
    Q_PROPERTY(int fontSize READ fontSize NOTIFY changed)
    Q_PROPERTY(int indentWidth READ indentWidth NOTIFY changed)
    Q_PROPERTY(bool useTabs READ useTabs NOTIFY changed)
    Q_PROPERTY(bool autoCloseBrackets READ autoCloseBrackets NOTIFY changed)
    Q_PROPERTY(bool showMinimap READ showMinimap NOTIFY changed)

public:
    explicit SettingsController(QObject* parent = nullptr);

    bool darkTheme() const { return m_dark; }
    QString fontFamily() const { return m_fontFamily; }
    int fontSize() const { return m_fontSize; }
    int indentWidth() const { return m_indentWidth; }
    bool useTabs() const { return m_useTabs; }
    bool autoCloseBrackets() const { return m_autoClose; }
    bool showMinimap() const;                       // lives in the engine: Alt+M changes it too

    Q_INVOKABLE void setDarkTheme(bool on);
    Q_INVOKABLE void setFontFamily(const QString& name);
    Q_INVOKABLE void setFontSize(int size);
    Q_INVOKABLE void setIndentWidth(int width);
    Q_INVOKABLE void setUseTabs(bool on);
    Q_INVOKABLE void setAutoCloseBrackets(bool on);
    Q_INVOKABLE void setShowMinimap(bool on);

signals:
    void changed();

private:
    void applyToTabs();          // indentation and bracket closing, for every tab (also the ones opened later)
    void syncMinimap();          // Alt+M changed it: remember that too
    void store();

    bool m_dark = true;
    QString m_fontFamily = QStringLiteral("Noto Sans Mono");
    int m_fontSize = 16;
    int m_indentWidth = 4;
    bool m_useTabs = false;
    bool m_autoClose = true;
    bool m_lastMinimap = true;
};
