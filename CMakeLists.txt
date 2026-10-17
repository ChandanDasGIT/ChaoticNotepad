cmake_minimum_required(VERSION 3.16)

project(ChaoticNotepad VERSION 1.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appNotepadQtQuick
    main.cpp
)

# Output the compiled binary file as 'ChaoticNotepad' instead of 'appNotepadQtQuick'
set_target_properties(appNotepadQtQuick PROPERTIES
    OUTPUT_NAME "ChaoticNotepad"
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
        components/Minimap.qml
        components/editorComponents/EditorLineGutter.qml
        components/editorComponents/EditorKeyHandler.qml
    SOURCES
        fileio.h
        functions/textsercher/textsearcher.h
        functions/textsercher/textsearcher.cpp
        functions/highlighter/cpphighlighter.h
        functions/highlighter/cpphighlighter.cpp
        functions/linediff/linediffer.h
        functions/linediff/linediffer.cpp
        functions/multicursor/multicursor.h
        functions/multicursor/multicursor.cpp
        functions/minimapview/minimapview.h
        functions/minimapview/minimapview.cpp
        functions/appcontroller/appcontroller.h
        functions/appcontroller/appcontroller.cpp
        functions/stickyscroll/stickyscroll.h
        functions/stickyscroll/stickyscroll.cpp
)

target_include_directories(appNotepadQtQuick PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/textsercher
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/highlighter
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/linediff
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/multicursor
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/minimapview
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/appcontroller
    ${CMAKE_CURRENT_SOURCE_DIR}/functions/stickyscroll
)

target_link_libraries(appNotepadQtQuick PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
)

# Installation targets for packaging & desktop integration
include(GNUInstallDirs)

install(TARGETS appNotepadQtQuick
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ChaoticNotepad.desktop")
    install(FILES ChaoticNotepad.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    )
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ChaoticNotepad.svg")
    install(FILES ChaoticNotepad.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    )
endif()

