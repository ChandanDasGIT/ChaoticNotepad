#include "wrapper/gutter/guttermodel.h"

GutterModel::GutterModel(QObject* parent) : QAbstractListModel(parent) {}

int GutterModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_count;
}

QHash<int, QByteArray> GutterModel::roleNames() const {
    return {
        {LineNumberRole, "lineNumber"}, {FoldRole, "fold"},
        {ChangeRole, "change"},         {IsCursorLineRole, "isCursorLine"}
    };
}

QVariant GutterModel::data(const QModelIndex& index, int role) const {
    if (!m_builder || !m_tab || !index.isValid() || index.row() < 0 || index.row() >= m_count)
        return QVariant();

    if (m_cachedIndex != index.row()) {
        m_cached = m_builder->row(*m_tab, static_cast<size_t>(index.row()));
        m_cachedIndex = index.row();
    }
    switch (role) {
    case LineNumberRole:   return m_cached.lineNumber;
    case FoldRole:         return m_cached.fold;
    case ChangeRole:       return m_cached.change;
    case IsCursorLineRole: return m_cached.isCursorLine;
    default:               return QVariant();
    }
}

void GutterModel::refresh(const RowBuilder* builder, const EditorTab* tab) {
    const int now = builder ? static_cast<int>(builder->rowCount()) : 0;
    const int tabId = tab ? tab->id : -1;
    const int change = now > m_count ? now - m_count : m_count - now;
    if (tabId != m_tabId || change > 1) {                 // another tab, or many rows at once: start the list again from scratch
        m_tabId = tabId;
        beginResetModel();
        m_builder = builder;
        m_tab = tab;
        m_cachedIndex = -1;
        m_count = now;
        endResetModel();
        return;
    }
    m_builder = builder;
    m_tab = tab;
    m_cachedIndex = -1;
    if (now > m_count) {
        beginInsertRows(QModelIndex(), m_count, now - 1);
        m_count = now;
        endInsertRows();
    } else if (now < m_count) {
        beginRemoveRows(QModelIndex(), now, m_count - 1);
        m_count = now;
        endRemoveRows();
    }
    if (m_count > 0)
        emit dataChanged(index(0), index(m_count - 1));
}
