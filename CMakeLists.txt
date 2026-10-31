cmake_minimum_required(VERSION 3.16)

project(ChaoticNotepad VERSION 2.3.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Quick Network)

qt_standard_project_setup(REQUIRES 6.10)

# ---------------------------------------------------------------- the engine (no Qt)
# Everything under backend/textengine is plain C++17. It is built as its own library and does not
# link to Qt, so it stays independent of the UI.
file(GLOB_RECURSE ENGINE_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_LIST_DIR}/backend/textengine/*.cpp")

add_library(textengine STATIC ${ENGINE_SOURCES})
target_include_directories(textengine PUBLIC "${CMAKE_CURRENT_LIST_DIR}/backend")
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(textengine PRIVATE -Wall -Wextra)
endif()

# ---------------------------------------------------------------- the app
# wrapper/  : QObject classes that connect the engine to QML (any subfolders)
# frontend/ : the QML files (any subfolders). File names must start with a capital letter and be
#             unique across all subfolders, e.g. Minimap.qml, not minimap.qml.
file(GLOB_RECURSE WRAPPER_SOURCES CONFIGURE_DEPENDS RELATIVE "${CMAKE_CURRENT_LIST_DIR}"
    "${CMAKE_CURRENT_LIST_DIR}/wrapper/*.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/wrapper/*.h")

file(GLOB_RECURSE FRONTEND_QML CONFIGURE_DEPENDS RELATIVE "${CMAKE_CURRENT_LIST_DIR}"
    "${CMAKE_CURRENT_LIST_DIR}/frontend/*.qml")

set_source_files_properties(frontend/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(frontend/Icon.qml  PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(appChaoticNotepad
    main.cpp
    third_party/monocypher/monocypher.c
    third_party/monocypher/monocypher-ed25519.c
)

qt_add_qml_module(appChaoticNotepad
    URI ChaoticNotepad
    QML_FILES
        Main.qml
        ${FRONTEND_QML}
    SOURCES
        ${WRAPPER_SOURCES}
    RESOURCES
        frontend/fonts/fa-solid-900.ttf
)

target_include_directories(appChaoticNotepad PRIVATE "${CMAKE_CURRENT_LIST_DIR}")

# The version the About section shows. A release passes its tag (-DAPP_VERSION=2.4), other builds use the project version.
if(NOT DEFINED APP_VERSION)
    set(APP_VERSION "${PROJECT_VERSION}")
endif()
target_compile_definitions(appChaoticNotepad PRIVATE APP_VERSION="${APP_VERSION}")

# Qt's generated registration code includes the wrapper headers by bare file name,
# so every folder under wrapper/ has to be on the include path.
set(WRAPPER_DIRS "")
foreach(f ${WRAPPER_SOURCES})
    get_filename_component(d "${CMAKE_CURRENT_LIST_DIR}/${f}" DIRECTORY)
    list(APPEND WRAPPER_DIRS "${d}")
endforeach()
list(REMOVE_DUPLICATES WRAPPER_DIRS)
target_include_directories(appChaoticNotepad PRIVATE ${WRAPPER_DIRS})

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appChaoticNotepad PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appChaoticNotepad
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appChaoticNotepad
    PRIVATE Qt6::Quick Qt6::Network textengine
)

# Installation targets for packaging & desktop integration
include(GNUInstallDirs)

install(TARGETS appChaoticNotepad
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# `ChaoticNotepad` in a terminal (and in ChaoticNotepad.desktop) starts the app: a link next to the real program.
install(CODE "
    set(link \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/ChaoticNotepad\")
    file(REMOVE \"\${link}\")
    file(CREATE_LINK appChaoticNotepad \"\${link}\" SYMBOLIC)
")

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
