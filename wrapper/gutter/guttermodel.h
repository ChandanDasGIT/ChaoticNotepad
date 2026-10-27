#pragma once
#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>
#include "wrapper/editor/rowbuilder.h"

// The list of rows the gutter draws: line number, fold arrow, change mark, "this is the cursor line".
// It has the same rows, in the same order, as the text area, so the two lists stay side by side.
class GutterModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    enum Role { LineNumberRole = Qt::UserRole + 1, FoldRole, ChangeRole, IsCursorLineRole };

    explicit GutterModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Call after RowBuilder::update(). Adds or removes rows at the end and never resets the model.
    void refresh(const RowBuilder* builder, const EditorTab* tab);
    int m_tabId = -1;

private:
    const RowBuilder* m_builder = nullptr;
    const EditorTab* m_tab = nullptr;
    int m_count = 0;

    mutable int m_cachedIndex = -1;
    mutable RowData m_cached;
};
