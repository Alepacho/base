set(TEST_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Playground: manual experiments, prints to the console.
add_executable(playground
    ${TEST_SRC_DIR}/main.m
    ${TEST_SRC_DIR}/basic/test.m
    ${TEST_SRC_DIR}/basic/entity.m
    ${TEST_SRC_DIR}/selectors/test.m
    ${TEST_SRC_DIR}/files/test.m
    ${TEST_SRC_DIR}/threads/test.m
)
target_include_directories(playground PRIVATE ${TEST_SRC_DIR})
target_link_libraries(playground PRIVATE base)
target_compile_options(playground PRIVATE -fno-objc-arc -Wall)
# .vscode/launch.json expects the binary in bin/
set_target_properties(playground PROPERTIES
    C_STANDARD 11
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}/bin")

# Unit tests: run with `ctest`.
add_executable(base_tests ${TEST_SRC_DIR}/unit/main.m)
target_link_libraries(base_tests PRIVATE base)
target_compile_options(base_tests PRIVATE -fno-objc-arc -Wall)
set_target_properties(base_tests PROPERTIES C_STANDARD 11)
add_test(NAME base_tests
    COMMAND base_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

if(WIN32)
    foreach(target playground base_tests)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_RUNTIME_DLLS:${target}>
            $<TARGET_FILE_DIR:${target}>
            COMMAND_EXPAND_LISTS)
    endforeach()
endif()
