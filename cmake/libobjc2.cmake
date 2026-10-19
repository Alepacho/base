# Finds libobjc2 for Linux and Windows and sets BASE_OBJC2_TARGET to the
# target that base links. In order:
#
# 1. BASE_OBJC2_BUILD_DIR, when set: a libobjc2 build tree, whose sources are
#    in BASE_OBJC2_DIR (the bundled submodule by default).
# 2. An `objc` target that already exists, e.g. libobjc2 added to the parent
#    project with add_subdirectory().
# 3. An installed libobjc2, with find_package(libobjc). Add its prefix to
#    CMAKE_PREFIX_PATH if it is not in a standard location.
# 4. The bundled submodule, if it has been built in 3rdparty/libobjc2/build.

set(BASE_OBJC2_DIR "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libobjc2"
    CACHE PATH "libobjc2 source directory, used with BASE_OBJC2_BUILD_DIR")
set(BASE_OBJC2_BUILD_DIR ""
    CACHE PATH "libobjc2 build directory (empty: look for libobjc2)")

# Imports the libobjc2 built in `build_dir` from the sources in `source_dir`.
function(base_import_objc2_tree source_dir build_dir)
    if(WIN32)
        set(library "${build_dir}/objc.dll")
        set(implib "${build_dir}/objc.lib")
    else()
        set(library "${build_dir}/libobjc.so")
    endif()
    if(NOT EXISTS "${library}")
        message(FATAL_ERROR
            "libobjc2 is not built in '${build_dir}' (no ${library}), "
            "see README.md")
    endif()

    add_library(base_objc2 SHARED IMPORTED GLOBAL)
    set_target_properties(base_objc2 PROPERTIES IMPORTED_LOCATION "${library}")
    if(WIN32)
        set_target_properties(base_objc2 PROPERTIES IMPORTED_IMPLIB "${implib}")
    endif()

    # Only the public `objc/` headers: the libobjc2 source root also has
    # files like `selector.h` or `unwind.h` that would shadow other headers.
    set(include_dir "${CMAKE_CURRENT_BINARY_DIR}/objc2-include")
    file(COPY "${source_dir}/objc" DESTINATION "${include_dir}")
    # libobjc2 >= 2.2 generates objc-config.h in its build directory.
    if(EXISTS "${build_dir}/objc/objc-config.h")
        file(COPY "${build_dir}/objc/objc-config.h"
            DESTINATION "${include_dir}/objc")
    endif()
    set_target_properties(base_objc2 PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${include_dir}")

    message(STATUS "base: using the libobjc2 built in ${build_dir}")
endfunction()

if(BASE_OBJC2_BUILD_DIR)
    base_import_objc2_tree("${BASE_OBJC2_DIR}" "${BASE_OBJC2_BUILD_DIR}")
    set(BASE_OBJC2_TARGET base_objc2)
    return()
endif()

if(TARGET objc)
    message(STATUS "base: using the existing objc target")
    set(BASE_OBJC2_TARGET objc)
    return()
endif()

find_package(libobjc ${BASE_OBJC2_MIN_VERSION} CONFIG QUIET)
if(libobjc_FOUND AND TARGET objc)
    message(STATUS "base: using libobjc2 ${libobjc_VERSION} from ${libobjc_DIR}")
    set(BASE_OBJC2_TARGET objc)
    return()
endif()

set(bundled_build "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libobjc2/build")
if(EXISTS "${bundled_build}/libobjc.so" OR EXISTS "${bundled_build}/objc.dll")
    base_import_objc2_tree("${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libobjc2"
        "${bundled_build}")
    set(BASE_OBJC2_TARGET base_objc2)
    return()
endif()

message(FATAL_ERROR
    "libobjc2 (>= ${BASE_OBJC2_MIN_VERSION}) was not found. Build the bundled "
    "one in 3rdparty/libobjc2/build, install one and add its prefix to "
    "CMAKE_PREFIX_PATH, or set BASE_OBJC2_BUILD_DIR. See README.md.")
