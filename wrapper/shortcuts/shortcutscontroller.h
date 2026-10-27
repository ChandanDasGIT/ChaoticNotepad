#pragma once
#include <QHash>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// The list of keyboard shortcuts, and the keys the user chose for them (ShortcutsController in QML).
//
// How a changed shortcut works: every action has a key the engine already understands (its "built-in key",
// for example Ctrl+S for Save). When the user gives an action another key, EditorController::keyPressed asks
// remap() about every key first. The new key is turned back into the built-in key before the engine sees it,
// and the built-in key of a changed action is swallowed, so it no longer does anything.
//
// The user's choices are saved with QSettings (only the ones that differ from the built-in keys).
class ShortcutsController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // [ { title, items: [ { id, what, fixed, changed, keys, defaultKeys } ] } ]
    //   keys / defaultKeys: a list of ways to do it; each way is a list of key names ["Ctrl", "Shift", "S"]
    Q_PROPERTY(QVariantList sections READ sections NOTIFY changed)
    Q_PROPERTY(bool anyChanged READ anyChanged NOTIFY changed)

public:
    static ShortcutsController* instance();
    static ShortcutsController* create(QQmlEngine*, QJSEngine*);

    enum class Remap {
        None,        // not a shortcut that was changed: handle the key as it is
        Remapped,    // key and modifiers were replaced by the built-in key of the action
        Blocked      // the built-in key of an action that now has another key: do nothing
    };
    // Called for every key press with Qt's key and modifier values. Changes them when the result is Remapped.
    Remap remap(int& key, int& modifiers) const;

    QVariantList sections() const;
    bool anyChanged() const;

    // `key` and `modifiers` are the values of a Qt key event (event.key, event.modifiers).
    // Returns "" when the shortcut was changed, otherwise the reason it was not, ready to show to the user.
    Q_INVOKABLE QString setShortcut(const QString& id, int key, int modifiers);
    Q_INVOKABLE void reset(const QString& id);          // one action back to its built-in key
    Q_INVOKABLE void resetAll();                        // every action back to its built-in key

signals:
    void changed();

private:
    explicit ShortcutsController(QObject* parent = nullptr);

    struct Combo {
        int key = 0;                 // a Qt::Key
        int mods = 0;                // Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier
        int code() const { return key | mods; }
        bool operator==(const Combo& o) const { return key == o.key && mods == o.mods; }
    };
    struct Action {
        QString id;
        QString section;
        QString title;
        Combo builtIn;               // the key the engine understands
        Combo current;               // the key the user uses now
        bool rebindable = true;
        QString fixedKeys;           // only for a shortcut that cannot change: "Ctrl+Tab / Ctrl+PageDown"
    };

    void add(const QString& section, const QString& id, const QString& title, int key, int mods);
    void addFixed(const QString& section, const QString& title, const QString& keys);
    void reserve(int key, int mods);
    void rebuild();                                      // the lookup tables, after any change
    void store() const;
    void load();
    Action* find(const QString& id);

    static void normalise(int& key, int& mods);
    static QStringList caps(const Combo& c);             // ["Ctrl", "Shift", "S"]
    static QVariantList capsOfFixed(const QString& keys);

    QVector<Action> m_actions;
    QSet<int> m_reserved;                                // keys that belong to fixed shortcuts: they cannot be given away
    QHash<int, int> m_byCode;                            // key -> index of the action that uses it now
    QSet<int> m_blocked;                                 // built-in keys that no action uses now
};
