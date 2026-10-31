import QtQuick
import QtQuick.Controls.Basic

// The text editor: the text rows, pinned header lines, cursor, selection, mouse and keyboard. It draws what
// the wrapper gives it and reports what the user does. It never edits text itself.
// The gutter is a separate component placed next to it (Gutter.qml). Main.qml connects the two:
//     Gutter { contentY: editor.contentY; cellWidth: editor.cellWidth; onScrolled: (dy) => editor.scrollBy(dy) }
//     CodeEditor { id: editor }
//
// ====================================================================================================
// WHAT THE WRAPPER MUST PROVIDE: the singleton EditorController (registered in the module with QML_SINGLETON)
//
//   rows            a list model with one item per VISIBLE row (folds and word wrap already applied).
//                   Roles of each row:
//                     lineNumber   int     1-based; 0 for the continuation of a wrapped line
//                     length       int     the row's text length in cells
//                     spans        list    [{start:int, text:string, kind:int, bold:bool, italic:bool, underline:bool}]
//                                          coloured pieces, start in cells, tabs already turned into spaces;
//                                          kind = the engine's Token number
//                     selection    list    [{from:int, to:int}] selected cells; to == length + 1 selects the line break
//                     cursors      list    [{cell:int, main:bool}]
//                     matches      list    [{from:int, to:int, current:bool}]  find matches
//                     brackets     list    [cell:int, ...]  brackets to highlight
//                     fold         int     the gutter arrow: 0 nothing, 1 can be folded (open), 2 folded
//                     foldPill     bool    draw the "..." after the text (the last row of a folded header)
//                     foldSelected bool    that "..." is selected
//                     foldTail     string  text after the "..." of a folded line, e.g. "}"
//                     change       int     0 untouched, 1 unsaved, 2 saved
//                     isCursorLine bool
//   gutterDigits    int    digits of the largest line number (used by the gutter)
//   sticky          list   the pinned header lines for the current first row:
//                          [{row:int, lineNumber:int, length:int, spans:[...]}]  (row = the row to jump to)
//
//   Methods (Q_INVOKABLE) called by the editor:
//     viewportChanged(columns, visibleRows, firstRow)    the width in cells, the height in rows, the top row
//     mousePress(row, cell, button, modifiers, clicks)   button: Qt.LeftButton ...; clicks: 1, 2 or 3
//     mouseDrag(row, cell)
//     mouseRelease()
//     toggleFold(row)                                    (called by the gutter)
//     stickyClicked(index)                               index of the pinned line that was clicked, 0 = the first
//     keyPressed(key, text, modifiers) -> bool           true when the engine used the key
//
//   Signal the editor listens to:
//     scrollRequested(topRow)                            show this row as the first one
//
//   The font comes from Theme.editorFontFamily and Theme.editorFontSize.
// ====================================================================================================
Item {
    id: root

    focus: true
    activeFocusOnTab: true
    clip: true

    // ---- measures ----
    readonly property real rowHeight: Theme.editorLineHeight
    readonly property real cellWidth: metrics.advanceWidth / 100
    readonly property real textRoom: textArea.width - Theme.textPadding - Theme.scrollbarWidth
    readonly property int columns: Math.max(1, Math.floor(textRoom / cellWidth) - 1)   // -1 keeps room for the cursor at line end
    readonly property int visibleRows: Math.max(1, Math.floor(height / rowHeight))
    readonly property int firstRow: Math.max(0, Math.floor(list.contentY / rowHeight))
    readonly property real stickyHeight: stickyColumn.height

    property bool cursorOn: true
    property bool pointerHidden: false        // typing hid the mouse pointer; moving the mouse or a click brings it back

    // what the gutter needs to stay in step with the text
    property alias contentY: list.contentY
    function scrollBy(dy) {
        const most = Math.max(0, list.contentHeight - list.height)
        list.contentY = Math.max(0, Math.min(most, list.contentY + dy))
    }

    TextMetrics {
        id: metrics
        font.family: Theme.editorFontFamily
        font.pixelSize: Theme.editorFontSize
        text: "M".repeat(100)                 // 100 characters: the width of one cell comes out exact
    }

    // ---- tell the wrapper how much room there is and where we are ----
    function report() {
        EditorController.viewportChanged(root.columns, root.visibleRows, root.firstRow)
    }
    onColumnsChanged: Qt.callLater(report)
    onVisibleRowsChanged: Qt.callLater(report)
    onFirstRowChanged: Qt.callLater(report)
    Component.onCompleted: Qt.callLater(report)

    Connections {
        target: EditorController
        function onScrollRequested(topRow) {
            list.forceLayout()    // the rows may have just been replaced: lay them out first
            const most = Math.max(0, list.count * root.rowHeight - list.height)    // from the row count: contentHeight is still the old tab's right after a switch
            list.contentY = Math.max(0, Math.min(most, topRow * root.rowHeight))
            root.report()          // always tell the wrapper where we really are (the scroll may have been limited)
        }
    }

    // ---- backgrounds ----
    Rectangle {
        anchors.fill: parent
        color: Theme.editorBg
    }

    // ---- the text ----
    Item {
        id: textArea
        anchors.fill: parent
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            model: EditorController.rows
            interactive: false                // the mouse selects text; the wheel and the scrollbar scroll
            clip: true
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            //------scrollbar------
            // ScrollBar.vertical: ScrollBar {
            //     id: vbar
            //     policy: ScrollBar.AsNeeded
            //     implicitWidth: Theme.scrollbarWidth
            //     contentItem: Rectangle {
            //         implicitWidth: Theme.scrollbarWidth
            //         color: vbar.pressed ? Theme.scrollbarHandlePressed
            //                             : vbar.hovered ? Theme.scrollbarHandleHover : Theme.scrollbarHandle
            //         opacity: vbar.active ? 1.0 : 0.7
            //     }
            //     background: Item { }
            // }

            delegate: EditorRow {
                required property var model

                width: list.width
                height: root.rowHeight
                cellWidth: root.cellWidth
                cursorVisible: root.cursorOn && root.activeFocus

                length: model.length
                spans: model.spans
                selection: model.selection
                cursors: model.cursors
                matches: model.matches
                brackets: model.brackets
                foldTail: model.foldTail
                foldPill: model.foldPill
                foldSelected: model.foldSelected
                isCursorLine: model.isCursorLine
            }
        }

        // ---- pinned header lines (sticky scroll) ----
        Column {
            id: stickyColumn
            anchors.top: parent.top
            anchors.left: parent.left
            width: list.width - Theme.scrollbarWidth

            Repeater {
                model: EditorController.sticky
                EditorRow {
                    required property var modelData
                    width: stickyColumn.width
                    height: root.rowHeight
                    cellWidth: root.cellWidth
                    opaque: true
                    cursorVisible: false

                    length: modelData.length
                    spans: modelData.spans
                }
            }
        }
        Rectangle {                           // the line under the pinned lines
            visible: stickyColumn.height > 0
            y: stickyColumn.height
            width: stickyColumn.width
            height: 1
            color: Theme.stickyDivider
        }

        // ---- the mouse: clicks and drags in the text, and the pinned lines ----
        MouseArea {
            id: mouse
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: Theme.scrollbarWidth     // the scrollbar keeps its own strip
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: root.pointerHidden ? Qt.BlankCursor : Qt.IBeamCursor
            hoverEnabled: root.pointerHidden                // moves without a button only matter while it is hidden

            property bool dragging: false
            property bool hiddenPosKnown: false
            property point hiddenPos
            property int clicks: 0
            property double lastPressTime: 0
            property real lastPressX: 0
            property real lastPressY: 0

            // function rowAt(y) {   //old code
            //     return Math.max(0, Math.min(list.count - 1, Math.floor((y + list.contentY) / root.rowHeight)))
            // }

            function rowAt(y) {
                const i = list.indexAt(1, y + list.contentY)      // the row under the pointer, whatever the scroll position
                return Math.max(0, Math.min(list.count - 1, i >= 0 ? i : Math.floor((y + list.contentY) / root.rowHeight)))
            }
            function cellAt(x) {
                return Math.max(0, Math.round((x - Theme.textPadding) / root.cellWidth))
            }
            function dragTo(x, y) {
                EditorController.mouseDrag(rowAt(y), cellAt(x))
            }

            onPressed: (m) => {
                root.pointerHidden = false
                root.forceActiveFocus()
                root.cursorOn = true
                blink.restart()

                if (m.y < root.stickyHeight) {                   // a pinned line
                    if (m.button === Qt.LeftButton)
                        EditorController.stickyClicked(Math.floor(m.y / root.rowHeight))
                    return
                }

                // single, double and triple click
                const now = Date.now()
                const near = Math.abs(m.x - lastPressX) < 4 && Math.abs(m.y - lastPressY) < 4
                if (now - lastPressTime < Application.styleHints.mouseDoubleClickInterval && near)
                    clicks = clicks >= 3 ? 1 : clicks + 1
                else
                    clicks = 1
                lastPressTime = now
                lastPressX = m.x
                lastPressY = m.y

                dragging = m.button === Qt.LeftButton
                EditorController.mousePress(rowAt(m.y), cellAt(m.x), m.button, m.modifiers, clicks)
            }
            onPositionChanged: (m) => {
                if (root.pointerHidden) {                        // Qt also reports a still pointer when the text changes: only a new place counts
                    if (!hiddenPosKnown) { hiddenPos = Qt.point(m.x, m.y); hiddenPosKnown = true }
                    else if (m.x !== hiddenPos.x || m.y !== hiddenPos.y) root.pointerHidden = false
                }
                if (!dragging) return
                if (m.y < root.stickyHeight || m.y > root.height)    // outside the text: keep scrolling
                    autoScroll.start()
                else
                    autoScroll.stop()
                dragTo(m.x, m.y)
            }
            onReleased: {
                if (dragging) EditorController.mouseRelease()
                dragging = false
                autoScroll.stop()
            }

            Timer {
                id: autoScroll
                interval: 40
                repeat: true
                onTriggered: {
                    const top = root.stickyHeight
                    let delta = 0
                    if (mouse.mouseY < top) delta = mouse.mouseY - top
                    else if (mouse.mouseY > root.height) delta = mouse.mouseY - root.height
                    delta = Math.max(-3, Math.min(3, delta / root.rowHeight)) * root.rowHeight
                    const most = Math.max(0, list.contentHeight - list.height)
                    list.contentY = Math.max(0, Math.min(most, list.contentY + delta))
                    mouse.dragTo(mouse.mouseX, Math.max(top, Math.min(root.height - 1, mouse.mouseY)))
                }
            }
        }
    }

    // ---- the cursor blinks ----
    Timer {
        id: blink
        interval: Math.max(1, Application.styleHints.cursorFlashTime / 2)
        repeat: true
        running: root.activeFocus && Application.styleHints.cursorFlashTime > 0
        onTriggered: root.cursorOn = !root.cursorOn
    }
    onActiveFocusChanged: { root.cursorOn = true; blink.restart(); root.pointerHidden = false }

    // ---- the keyboard ----
    Keys.onShortcutOverride: (event) => {
        // keys with Ctrl or Alt are for the editor, not for window shortcuts
        event.accepted = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0
    }
    Keys.onPressed: (event) => {
        if (EditorController.keyPressed(event.key, event.text, event.modifiers)) {
            event.accepted = true
            root.cursorOn = true
            blink.restart()
            // typing: a key that gives text (also Enter, Backspace, Tab), not a shortcut
            if (SettingsController.hidePointerWhileTyping && event.text !== "" && event.key !== Qt.Key_Escape
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                if (!root.pointerHidden) mouse.hiddenPosKnown = false
                root.pointerHidden = true
            }
        }
    }

    // ---- the mouse wheel ----
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y
                                                 : event.angleDelta.y / 120 * Theme.wheelRows * root.rowHeight
            root.scrollBy(-dy)
        }
    }
}
