#pragma once
#include <QString>

// Session restore (the "Restore tabs on start" setting). When it is on, quitting asks nothing: every tab is written to
// ~/.local/state/ChaoticNotepad/session (unsaved text and untitled tabs included, the folder readable only by you)
// and the next start opens them again, with the same tab in front and the cursors where they were.
// Files with no unsaved changes are read again from disk; only unsaved text is kept in the session folder.
//
// Only one window owns the session (a lock file next to the folder): a second window opened meanwhile asks about
// unsaved changes as before, so two windows never overwrite each other's tabs.
namespace Session {

bool enabled();                 // the setting (SettingsController keeps it)
void clear();                   // the setting was switched off: no copy of unsaved text stays behind
void restore();                 // at start, before the files named on the command line open
bool saveForQuit();             // true: written, the program may quit without asking about unsaved tabs
bool savedForQuit();            // this quit wrote the session (the update then need not pass the open files on)
QString folder();

}
