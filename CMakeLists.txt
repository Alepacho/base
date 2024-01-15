cmake_minimum_required(VERSION 3.27)

set(LIBRARY_NAME "base")
project(${LIBRARY_NAME})
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -Wall -g -O0")
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-objc-arc")

if(NOT APPLE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fobjc-runtime=gnustep-2.0 -fuse-ld=lld")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fblocks -fobjc-exceptions -fexceptions -fno-strict-aliasing")

    # set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Xclang -fblocks -Xclang -fobjc-exceptions -Xclang -fexceptions -fno-strict-aliasing")
    # set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DGNUSTEP -DGNUSTEP_BASE_LIBRARY=1 -DGNU_GUI_LIBRARY=1 -DGNU_RUNTIME=1 -DGNUSTEP_BASE_LIBRARY=1 -DGNUSTEP_WITH_DLL")
endif()

set(OBJC2_DIR ${CMAKE_CURRENT_LIST_DIR}/3rdparty/libobjc2/)
set(SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/src/)
set(INC_DIR ${CMAKE_CURRENT_LIST_DIR}/include/)

link_directories(${CMAKE_SOURCE_DIR}/lib)

set(SOURCES
    ${SRC_DIR}base.m
    ${SRC_DIR}system.m
    ${SRC_DIR}array.m
    ${SRC_DIR}string.m
    ${SRC_DIR}exception.m
    ${SRC_DIR}selector.m
    ${SRC_DIR}file.m
    ${SRC_DIR}thread.m
)

add_library(${LIBRARY_NAME} STATIC ${SOURCES})

if(NOT APPLE)
    # Copy objc2 library
    add_custom_command(TARGET ${LIBRARY_NAME} PRE_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${OBJC2_DIR}build/objc.lib"
        $<TARGET_FILE_DIR:${LIBRARY_NAME}>)

    if(WIN32)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${OBJC2_DIR}build/objc.dll"
            $<TARGET_FILE_DIR:${PROJECT_NAME}>)
    else()
        message(FATAL_ERROR "UNIX support is not implemented yet.")
    endif()

    # Copy objc2 headers
    file(COPY "${OBJC2_DIR}objc/" DESTINATION ${INC_DIR}/objc)
endif()

target_include_directories(${LIBRARY_NAME}
    PUBLIC
    ${INC_DIR}
)

target_link_libraries(${LIBRARY_NAME}
    PUBLIC
    objc
)

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/test)
