#include "wrapper/gutter/guttercontroller.h"
#include <QVariantMap>
#include "wrapper/editor/editorcontroller.h"

GutterController::GutterController(QObject* parent) : QObject(parent), m_rows(this) {
    EditorController* editor = EditorController::instance();
    connect(editor, &EditorController::rowsRebuilt, this, &GutterController::refresh);
    connect(editor, &EditorController::stickyChanged, this, &GutterController::refreshSticky);
    refresh();
    refreshSticky();
}

void GutterController::refresh() {
    EditorController* editor = EditorController::instance();
    m_rows.refresh(&editor->builder(), &editor->currentTab());
    if (m_digits != editor->builder().gutterDigits()) {
        m_digits = editor->builder().gutterDigits();
        emit gutterDigitsChanged();
    }
}

void GutterController::refreshSticky() {
    QVariantList list;
    for (const QVariant& v : EditorController::instance()->stickyList()) {
        QVariantMap m;
        m["lineNumber"] = v.toMap().value("lineNumber");
        list.append(m);
    }
    if (list != m_sticky) {
        m_sticky = list;
        emit stickyChanged();
    }
}

void GutterController::toggleFold(int row) { EditorController::instance()->toggleFold(row); }
void GutterController::stickyClicked(int index) { EditorController::instance()->stickyClicked(index); }
