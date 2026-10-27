#include "wrapper/editor/editorrowsmodel.h"
#include <QVariantMap>

EditorRowsModel::EditorRowsModel(QObject* parent) : QAbstractListModel(parent) {}

int EditorRowsModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_count;
}

QHash<int, QByteArray> EditorRowsModel::roleNames() const {
    return {
        {LengthRole, "length"},           {SpansRole, "spans"},
        {SelectionRole, "selection"},     {CursorsRole, "cursors"},
        {MatchesRole, "matches"},         {BracketsRole, "brackets"},
        {FoldPillRole, "foldPill"},       {FoldSelectedRole, "foldSelected"},
        {FoldTailRole, "foldTail"},       {IsCursorLineRole, "isCursorLine"}
    };
}

QVariantList EditorRowsModel::spansToVariant(const std::vector<RowSpan>& spans) {
    QVariantList list;
    list.reserve(static_cast<qsizetype>(spans.size()));
    for (const RowSpan& s : spans) {
        QVariantMap m;
        m["start"] = s.start;
        m["text"] = QString::fromStdString(s.text);
        m["kind"] = s.kind;
        m["bold"] = s.bold;
        m["italic"] = s.italic;
        m["underline"] = s.underline;
        list.append(m);
    }
    return list;
}

QVariant EditorRowsModel::data(const QModelIndex& index, int role) const {
    if (!m_builder || !m_tab || !index.isValid() || index.row() < 0 || index.row() >= m_count)
        return QVariant();

    if (m_cachedIndex != index.row()) {
        m_cached = m_builder->row(*m_tab, static_cast<size_t>(index.row()));
        m_cachedIndex = index.row();
    }
    const RowData& r = m_cached;

    switch (role) {
    case LengthRole:       return r.length;
    case SpansRole:        return spansToVariant(r.spans);
    case SelectionRole: {
        QVariantList l;
        for (const CellRange& c : r.selection) {
            QVariantMap m;
            m["from"] = c.from;
            m["to"] = c.to;
            l.append(m);
        }
        return l;
    }
    case CursorsRole: {
        QVariantList l;
        for (const RowCursor& c : r.cursors) {
            QVariantMap m;
            m["cell"] = c.cell;
            m["main"] = c.main;
            l.append(m);
        }
        return l;
    }
    case MatchesRole: {
        QVariantList l;
        for (const RowMatch& c : r.matches) {
            QVariantMap m;
            m["from"] = c.from;
            m["to"] = c.to;
            m["current"] = c.current;
            l.append(m);
        }
        return l;
    }
    case BracketsRole: {
        QVariantList l;
        for (int c : r.brackets) l.append(c);
        return l;
    }
    case FoldPillRole:     return r.foldPill;
    case FoldSelectedRole: return r.foldSelected;
    case FoldTailRole:     return QString::fromStdString(r.foldTail);
    case IsCursorLineRole: return r.isCursorLine;
    default:               return QVariant();
    }
}

void EditorRowsModel::refresh(const RowBuilder* builder, const EditorTab* tab) {
    const int now = builder ? static_cast<int>(builder->rowCount()) : 0;
    const int tabId = tab ? tab->id : -1;
    if (tabId != m_tabId) {                               // another tab: start the list again from scratch
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
    m_cachedIndex = -1;                                   // the old answer may be out of date
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
        emit dataChanged(index(0), index(m_count - 1));   // all roles
}
