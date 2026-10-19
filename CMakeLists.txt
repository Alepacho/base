cmake_minimum_required(VERSION 3.27)

# The version lives in include/base/version.h, so that code can check it too.
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/include/base/version.h BASE_VERSION_LINES
    REGEX "^#define BASE_VERSION_(MAJOR|MINOR|PATCH) ")
foreach(line ${BASE_VERSION_LINES})
    string(REGEX MATCH "BASE_VERSION_([A-Z]+) ([0-9]+)" _ "${line}")
    set(BASE_VERSION_${CMAKE_MATCH_1} ${CMAKE_MATCH_2})
endforeach()

# Objective-C sources are compiled by the C compiler (clang picks the
# language from the .m extension), so only C has to be enabled.
project(base
    VERSION ${BASE_VERSION_MAJOR}.${BASE_VERSION_MINOR}.${BASE_VERSION_PATCH}
    DESCRIPTION "Utilities for Objective-C without Foundation"
    HOMEPAGE_URL "https://github.com/Alepacho/base"
    LANGUAGES C)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "base supports 64-bit platforms only")
endif()

option(BASE_BUILD_TESTS "Build base tests and the playground" ${PROJECT_IS_TOP_LEVEL})
option(BASE_INSTALL "Generate the install rules of base" ${PROJECT_IS_TOP_LEVEL})
option(BASE_SANITIZE "Build base with AddressSanitizer and UBSan" OFF)
option(BASE_WERROR "Treat compiler warnings in base and its tests as errors" OFF)
if(NOT APPLE)
    option(BASE_USE_LLD
        "Link the targets that use base with lld (see README.md)" ON)
endif()

if(PROJECT_IS_TOP_LEVEL)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

# Oldest libobjc2 that works (see README.md), on Linux and Windows.
set(BASE_OBJC2_MIN_VERSION 2.2)

include(GNUInstallDirs)

set(BASE_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_library(base STATIC
    ${BASE_SRC_DIR}/base.m
    ${BASE_SRC_DIR}/system.m
    ${BASE_SRC_DIR}/array.m
    ${BASE_SRC_DIR}/dictionary.m
    ${BASE_SRC_DIR}/string.m
    ${BASE_SRC_DIR}/exception.m
    ${BASE_SRC_DIR}/selector.m
    ${BASE_SRC_DIR}/file.m
    ${BASE_SRC_DIR}/thread.m
)
add_library(base::base ALIAS base)

set_target_properties(base PROPERTIES
    C_STANDARD 11
    VERSION ${PROJECT_VERSION})

target_include_directories(base
    PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_compile_options(base
    PRIVATE
    -fno-objc-arc
    -Wall
    -Wextra
    -Wno-unused-parameter
    $<$<BOOL:${BASE_WERROR}>:-Werror>
    $<$<CONFIG:Debug>:-O0 -g>
)

# Only for this build tree: an installed base never forces sanitizers.
if(BASE_SANITIZE)
    target_compile_options(base PUBLIC
        $<BUILD_INTERFACE:-fsanitize=address,undefined -fno-omit-frame-pointer>)
    target_link_options(base PUBLIC
        $<BUILD_INTERFACE:-fsanitize=address,undefined>)
endif()

if(APPLE)
    # NSObject lives in the system libobjc.
    target_link_libraries(base PUBLIC objc)
else()
    include(cmake/libobjc2.cmake)

    # Everything that includes base headers needs the same runtime flags.
    target_compile_options(base
        PUBLIC
        -fobjc-runtime=gnustep-2.0
        -fblocks
        -fobjc-exceptions
        -fexceptions
        -fno-strict-aliasing
    )

    # A target that links base can still pick its own linker: set its
    # LINKER_TYPE property (CMake >= 3.29) or its BASE_NO_LLD property.
    if(BASE_USE_LLD)
        target_link_options(base INTERFACE
            "$<$<AND:$<STREQUAL:$<TARGET_PROPERTY:LINKER_TYPE>,>,$<NOT:$<BOOL:$<TARGET_PROPERTY:BASE_NO_LLD>>>>:-fuse-ld=lld>")
    endif()

    # In the build tree base uses the libobjc2 it was configured with,
    # once installed the one found by find_package(libobjc).
    target_link_libraries(base PUBLIC
        $<BUILD_INTERFACE:${BASE_OBJC2_TARGET}>
        $<INSTALL_INTERFACE:objc>)
endif()

if(BASE_INSTALL)
    include(CMakePackageConfigHelpers)

    install(TARGETS base
        EXPORT baseTargets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(DIRECTORY include/base
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(FILES LICENSE README.md
        DESTINATION ${CMAKE_INSTALL_DOCDIR})

    set(BASE_CMAKE_DIR ${CMAKE_INSTALL_LIBDIR}/cmake/base)
    install(EXPORT baseTargets
        NAMESPACE base::
        DESTINATION ${BASE_CMAKE_DIR})
    configure_package_config_file(cmake/baseConfig.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/baseConfig.cmake
        INSTALL_DESTINATION ${BASE_CMAKE_DIR})
    # 0.x releases may break the API between minor versions.
    write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/baseConfigVersion.cmake
        COMPATIBILITY SameMinorVersion)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/baseConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/baseConfigVersion.cmake
        DESTINATION ${BASE_CMAKE_DIR})
endif()

if(BASE_BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()
