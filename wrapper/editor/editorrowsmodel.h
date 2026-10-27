#pragma once
#include <QAbstractListModel>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include "wrapper/editor/rowbuilder.h"

// The list of rows the TEXT AREA draws (the line numbers, fold arrows and change marks belong to the gutter). QML reads it as EditorController.rows.
// It owns no text: it asks RowBuilder for a row when QML asks for one, and keeps the last answer
// so that the many role reads of one row cost only one build.
class EditorRowsModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    enum Role {
        LengthRole = Qt::UserRole + 1,
        SpansRole, SelectionRole, CursorsRole, MatchesRole, BracketsRole,
        FoldPillRole, FoldSelectedRole, FoldTailRole, IsCursorLineRole
    };

    explicit EditorRowsModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Call after RowBuilder::update(). Inserts or removes rows at the END when the count changed and
    // tells QML that every row may have changed. It never resets the model, so the list keeps its scroll position.
    void refresh(const RowBuilder* builder, const EditorTab* tab);
    int m_tabId = -1;                    // the tab the rows belong to: another tab means a full reset

    // Shared with the controller, which uses them for the pinned lines.
    static QVariantList spansToVariant(const std::vector<RowSpan>& spans);

private:
    const RowBuilder* m_builder = nullptr;
    const EditorTab* m_tab = nullptr;
    int m_count = 0;

    mutable int m_cachedIndex = -1;
    mutable RowData m_cached;
};
