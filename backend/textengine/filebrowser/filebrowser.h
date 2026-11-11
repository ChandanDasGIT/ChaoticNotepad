#pragma once
#include <cstddef>
#include <string>
#include <vector>

// The panel behind Open (Ctrl+O) and Save as (Ctrl+S on a new file, Alt+S).
// It lists one folder at a time. You walk through the folders, then pick a file (Open)
// or type a file name (Save as). The panel only keeps its own state: it never opens or writes files,
// and it knows nothing about screens. The front end draws it from the getters below.
class FileBrowser {
public:
    enum class Mode { Open, SaveAs };

    struct Result {
        enum Kind { None, Choose } kind = None;
        std::string path;       // Choose: the full path the user picked
        std::string message;    // None: a short hint for the status bar ("" = nothing to say)
    };

    // Starts the panel. `currentFile` is the open file's path ("" = none): the panel starts in its folder.
    void open(Mode mode, const std::string& currentFile);

    // How many list rows the front end can show at once. Scrolling and Page Up / Down depend on it.
    void setVisibleRows(int rows) { m_visible = rows < 1 ? 1 : rows; ensureVisible(); }

    // ---- keys ----
    void typeText(const std::string& s);   // Open: filters the list.  Save as: the file name.  "dir/" walks into dir.
    void backspace(bool wholeName);        // on an empty name: go up one folder
    void moveSelection(int delta);
    void selectFirst();
    void selectLast();
    void goUp();                           // parent folder
    void toggleHidden();                   // show or hide names that start with '.'
    Result activate();                     // Enter
    size_t pageRows() const;               // rows to jump for Page Up / Page Down

    // ---- the folder path at the top, edited: right-click it > Paste ----
    // While it is edited, typing, Backspace and pasting change the path instead of the field, Enter goes there
    // (an error leaves it open to fix) and Esc puts the folder back. Moving in the list or the folders ends it too.
    void editPath(const std::string& text);    // the path bar becomes an edit box holding `text` (cleaned, see goTo)
    void cancelPathEdit() { m_editingPath = false; m_error.clear(); }
    bool editingPath() const { return m_editingPath; }
    const std::string& pathText() const { return m_pathText; }

    // Right-click > Paste and go, or Enter in the edited path. Takes the first line, without spaces around it;
    // a file:// link becomes its path; ~ and relative paths work as in the field.
    // A folder: it is shown. A file (existing or new): Open picks it, Save as shows its folder and fills in the name.
    // Its folder does not exist: m_error says so and nothing moves.
    Result goTo(const std::string& path);

    // ---- mouse ----
    Result click(size_t row);              // a click on list row `row` (0-based, counted from the first entry, not the screen top);
                                           // a click selects, a second click on it within 400 ms = Enter
    void scroll(int rows);                 // mouse wheel: moves the first visible row, not the selection

    // ---- what the front end draws ----
    Mode mode() const { return m_mode; }
    std::string title() const;                         // "Open file" or "Save as"
    std::string shownDirectory() const;                // the folder, with the home folder shortened to ~ and a closing "/"
    std::string fieldLabel() const;                    // "Filter" (Open) or "Name" (Save as): the label of the text field
    const std::string& name() const { return m_name; } // the text typed into that field
    const std::string& directory() const { return m_dir; }   // the folder, absolute

    size_t rowCount() const { return m_view.size(); }  // entries shown (hidden files and filter applied); ".." comes first
    std::string rowName(size_t row) const;             // the entry's name (without a closing "/")
    bool rowIsDir(size_t row) const;
    size_t selectedRow() const { return m_sel; }
    size_t topRow() const { return m_top; }            // first row that is visible
    bool listHasFocus() const { return m_mode == Mode::Open || m_listFocus; }   // draw the selection strongly
    bool showHidden() const { return m_showHidden; }   // names that start with '.' are listed

    std::string emptyMessage() const;                  // what to show when there are no rows ("" = rows exist)
    const std::string& error() const { return m_error; }   // shown instead of the hint, until the next key
    std::string hint() const;                          // a line about the keys

private:
    struct Entry { std::string name; bool dir; };

    bool loadDir(const std::string& path);
    void rebuildView();
    void ensureVisible();
    void selectByName(const std::string& name);
    void enterEntry(const Entry& e, bool clearName);
    bool navigateFromName();
    std::string resolveName(const std::string& name) const;
    static std::string cleanPath(const std::string& text);   // see goTo

    Mode m_mode = Mode::Open;
    std::string m_dir;                 // the folder being shown (absolute)
    std::string m_name;                // Open: the filter text.  Save as: the file name
    std::string m_error;
    std::vector<Entry> m_all;          // everything in the folder: ".." first, then folders, then files
    std::vector<size_t> m_view;        // indexes into m_all that are shown (hidden files and filter applied)
    size_t m_sel = 0;                  // selected row, an index into m_view
    size_t m_top = 0;                  // first visible row
    bool m_showHidden = false;
    bool m_listFocus = false;          // Save as: true after Up/Down, so Enter acts on the selected row
    int m_visible = 15;                // list rows the front end can show
    bool m_editingPath = false;        // see editPath()
    std::string m_pathText;
    long long m_lastClickMs = 0;
    size_t m_lastClickIdx = 0;
};
