cmake_minimum_required(VERSION 3.27)

# Objective-C sources are compiled by the C compiler (clang picks the
# language from the .m extension), so only C has to be enabled.
project(base LANGUAGES C)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "base supports 64-bit platforms only")
endif()

option(BASE_BUILD_TESTS "Build base tests and the playground" ${PROJECT_IS_TOP_LEVEL})
option(BASE_SANITIZE "Build base with AddressSanitizer and UBSan" OFF)

if(PROJECT_IS_TOP_LEVEL)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

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

set_target_properties(base PROPERTIES C_STANDARD 11)

target_include_directories(base
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(base
    PRIVATE
    -fno-objc-arc
    -Wall
    $<$<CONFIG:Debug>:-O0 -g>
)

if(BASE_SANITIZE)
    target_compile_options(base PUBLIC -fsanitize=address,undefined -fno-omit-frame-pointer)
    target_link_options(base PUBLIC -fsanitize=address,undefined)
endif()

if(APPLE)
    # NSObject lives in the system libobjc.
    target_link_libraries(base PUBLIC objc)
else()
    # libobjc2 has to be built first, see README.md
    set(BASE_OBJC2_DIR "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libobjc2"
        CACHE PATH "libobjc2 source directory")
    set(BASE_OBJC2_BUILD_DIR "${BASE_OBJC2_DIR}/build"
        CACHE PATH "libobjc2 build directory")

    add_library(base_objc2 SHARED IMPORTED)
    if(WIN32)
        set_target_properties(base_objc2 PROPERTIES
            IMPORTED_IMPLIB "${BASE_OBJC2_BUILD_DIR}/objc.lib"
            IMPORTED_LOCATION "${BASE_OBJC2_BUILD_DIR}/objc.dll")
    else()
        set_target_properties(base_objc2 PROPERTIES
            IMPORTED_LOCATION "${BASE_OBJC2_BUILD_DIR}/libobjc.so")
    endif()

    # Only the public `objc/` headers: the libobjc2 source root also has
    # files like `selector.h` or `unwind.h` that would shadow other headers.
    set(BASE_OBJC2_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/objc2-include")
    file(COPY "${BASE_OBJC2_DIR}/objc" DESTINATION "${BASE_OBJC2_INCLUDE_DIR}")
    # libobjc2 >= 2.2 generates objc-config.h in its build directory.
    if(EXISTS "${BASE_OBJC2_BUILD_DIR}/objc/objc-config.h")
        file(COPY "${BASE_OBJC2_BUILD_DIR}/objc/objc-config.h"
            DESTINATION "${BASE_OBJC2_INCLUDE_DIR}/objc")
    endif()
    set_target_properties(base_objc2 PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${BASE_OBJC2_INCLUDE_DIR}")

    # Everything that includes base headers needs the same runtime flags.
    target_compile_options(base
        PUBLIC
        -fobjc-runtime=gnustep-2.0
        -fblocks
        -fobjc-exceptions
        -fexceptions
        -fno-strict-aliasing
    )
    target_link_options(base PUBLIC -fuse-ld=lld)
    target_link_libraries(base PUBLIC base_objc2)
endif()

if(BASE_BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()
