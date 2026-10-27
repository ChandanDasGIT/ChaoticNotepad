#include "wrapper/tabs/tabscontroller.h"
#include "wrapper/dialog/dialogcontroller.h"
#include "wrapper/editor/editorcontroller.h"

// ------------------------------------------------------------------ the model

TabsModel::TabsModel(QObject* parent) : QAbstractListModel(parent) {}

int TabsModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_titles.size());
}

QHash<int, QByteArray> TabsModel::roleNames() const {
    return {{TitleRole, "title"}, {ModifiedRole, "modified"}};
}

QVariant TabsModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_titles.size()) return QVariant();
    if (role == TitleRole) return m_titles.at(index.row());
    if (role == ModifiedRole) return m_modified.at(index.row());
    return QVariant();
}

void TabsModel::refresh(const QStringList& titles, const QList<bool>& modified) {
    const int old = static_cast<int>(m_titles.size());
    const int now = static_cast<int>(titles.size());
    if (titles == m_titles && modified == m_modified) return;

    if (now > old) {
        beginInsertRows(QModelIndex(), old, now - 1);
        m_titles = titles;
        m_modified = modified;
        endInsertRows();
    } else if (now < old) {
        beginRemoveRows(QModelIndex(), now, old - 1);
        m_titles = titles;
        m_modified = modified;
        endRemoveRows();
    } else {
        m_titles = titles;
        m_modified = modified;
    }
    if (now > 0) emit dataChanged(index(0), index(now - 1));
}

// ------------------------------------------------------------------ the controller

TabsController::TabsController(QObject* parent) : QObject(parent), m_model(this) {
    connect(EditorController::instance(), &EditorController::documentChanged, this, &TabsController::sync);
    sync();
}

void TabsController::sync() {
    TabManager& tabs = EditorController::instance()->tabs();
    QStringList titles;
    QList<bool> modified;
    for (size_t i = 0; i < tabs.count(); ++i) {
        titles << QString::fromStdString(tabs.title(i));
        modified << tabs.modified(i);
    }
    m_model.refresh(titles, modified);

    const int current = static_cast<int>(tabs.currentIndex());
    if (current != m_current) {
        m_current = current;
        emit currentChanged();
    }
}

void TabsController::select(int index) {
    EditorController* ed = EditorController::instance();
    if (index < 0 || static_cast<size_t>(index) >= ed->tabs().count()) return;
    ed->tabs().select(static_cast<size_t>(index));
    ed->changedOutside(false);
}

void TabsController::closeTab(int index) {
    EditorController* ed = EditorController::instance();
    if (index < 0 || static_cast<size_t>(index) >= ed->tabs().count()) return;
    DialogController::instance()->requestClose(static_cast<size_t>(index));
    ed->changedOutside(false);
}

void TabsController::newTab() {
    EditorController* ed = EditorController::instance();
    ed->tabs().newTab();
    ed->inputState().status = "new tab";
    ed->changedOutside(false);
}

void TabsModel::move(int from, int to) {
    const int n = static_cast<int>(m_titles.size());
    if (from == to || from < 0 || to < 0 || from >= n || to >= n) return;
    if (!beginMoveRows(QModelIndex(), from, from, QModelIndex(), to > from ? to + 1 : to)) return;
    m_titles.move(from, to);
    m_modified.move(from, to);
    endMoveRows();
}

void TabsController::moveTab(int from, int to) {
    EditorController* ed = EditorController::instance();
    const int n = static_cast<int>(ed->tabs().count());
    if (from < 0 || to < 0 || from >= n || to >= n || from == to) return;
    ed->tabs().move(static_cast<size_t>(from), static_cast<size_t>(to));
    ed->tabs().select(static_cast<size_t>(to));           // the tab you are dragging stays the current one
    m_model.move(from, to);                               // the tab bar slides the tabs
    ed->changedOutside(false);
}