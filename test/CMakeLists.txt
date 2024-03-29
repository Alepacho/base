cmake_minimum_required(VERSION 3.27)

set(PROJECT_NAME "playground")
project(${PROJECT_NAME})
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -Wall -g -O0")
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2")

if(NOT APPLE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fobjc-runtime=gnustep-2.0 -fuse-ld=lld")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fblocks -fobjc-exceptions -fexceptions -fno-strict-aliasing")
endif()

set(SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/src/)
set(BASE_DIR ${CMAKE_CURRENT_LIST_DIR}/../)
set(BASE_INC_DIR ${BASE_DIR}/include/)
set(BASE_LIB_DIR ${BASE_DIR}/lib/)

link_directories(${BASE_LIB_DIR})

set(SOURCES
    ${SRC_DIR}main.m
    ${SRC_DIR}basic/test.m
    ${SRC_DIR}basic/entity.m
    ${SRC_DIR}selectors/test.m
    ${SRC_DIR}files/test.m
    ${SRC_DIR}threads/test.m
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME}
    PUBLIC
    ${BASE_INC_DIR}
)

target_link_libraries(${PROJECT_NAME}
    PUBLIC
    base
)

if(NOT APPLE)
    target_link_libraries(${PROJECT_NAME}
        PUBLIC
        objc
    )

    if(WIN32)
        # Copy DLL File
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${BASE_LIB_DIR}/objc.dll"
            $<TARGET_FILE_DIR:${PROJECT_NAME}>)
    else()
        message(FATAL_ERROR "UNIX support is not implemented yet.")
    endif()
endif()