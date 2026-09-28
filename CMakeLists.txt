cmake_minimum_required(VERSION 3.16)

project(NotepadQtQuick VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appNotepadQtQuick
    main.cpp
    fileio.h
    functions/textsercher/textsearcher.h
    functions/textsercher/textsearcher.cpp
    functions/highlighter/cpphighlighter.h
    functions/highlighter/cpphighlighter.cpp
)

qt_add_qml_module(appNotepadQtQuick
    URI NotepadQtQuick
    VERSION 1.0
    QML_FILES
        Main.qml
        components/AppPalette.qml
        components/BottomToolbar.qml
        components/CodeEditor.qml
        components/CustomFileDialog.qml
        components/DocumentTabBar.qml
        components/ToolbarIcon.qml
        components/UnsavedPromptDialog.qml
        components/FindReplaceBar.qml
        components/TabController.qml
        components/SettingsDialog.qml
    SOURCES
        fileio.h
        functions/textsercher/textsearcher.h
        functions/textsercher/textsearcher.cpp
        functions/highlighter/cpphighlighter.h
        functions/highlighter/cpphighlighter.cpp
)

target_include_directories(appNotepadQtQuick PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/textsercher
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/highlighter
)

target_link_libraries(appNotepadQtQuick PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appNotepadQtQuick
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)