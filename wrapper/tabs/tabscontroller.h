#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// The list of tabs the tab bar draws: title and "has unsaved changes" for each.
class TabsModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    enum Role { TitleRole = Qt::UserRole + 1, ModifiedRole };

    explicit TabsModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Adds or removes rows at the end when the number of tabs changed and tells QML that every row may have changed.
    // The model is never reset, so the tab bar keeps its scroll position.
    void refresh(const QStringList& titles, const QList<bool>& modified);

    // Moves one row, so the tab bar slides the tab instead of redrawing every tab.
    void move(int from, int to);

private:
    QStringList m_titles;
    QList<bool> m_modified;
};

// What DocumentTabBar.qml talks to (TabsController in QML).
class TabsController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(TabsModel* tabs READ tabs CONSTANT)
    Q_PROPERTY(int current READ current NOTIFY currentChanged)

public:
    explicit TabsController(QObject* parent = nullptr);

    TabsModel* tabs() { return &m_model; }
    int current() const { return m_current; }

    Q_INVOKABLE void select(int index);
    Q_INVOKABLE void closeTab(int index);   // asks first when the tab has unsaved changes
    Q_INVOKABLE void newTab();
    Q_INVOKABLE void moveTab(int from, int to);   // drag and drop in the tab bar

signals:
    void currentChanged();

private:
    void sync();

    TabsModel m_model;
    int m_current = 0;
};
