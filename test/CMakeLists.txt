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
add_executable(base_tests
    ${TEST_SRC_DIR}/unit/main.m
    ${TEST_SRC_DIR}/unit/test_base.m
    ${TEST_SRC_DIR}/unit/test_string.m
    ${TEST_SRC_DIR}/unit/test_exception.m
    ${TEST_SRC_DIR}/unit/test_array.m
    ${TEST_SRC_DIR}/unit/test_dictionary.m
    ${TEST_SRC_DIR}/unit/test_file.m
    ${TEST_SRC_DIR}/unit/test_selector.m
    ${TEST_SRC_DIR}/unit/test_thread.m
    ${TEST_SRC_DIR}/unit/test_system.m
)
target_link_libraries(base_tests PRIVATE base)
target_compile_options(base_tests PRIVATE -fno-objc-arc -Wall
    $<$<BOOL:${BASE_WERROR}>:-Werror>)
set_target_properties(base_tests PROPERTIES C_STANDARD 11)
add_test(NAME base_tests
    COMMAND base_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

# Scenarios that terminate the process: only their output is checked.
add_test(NAME base_tests_fatal COMMAND base_tests fatal)
set_tests_properties(base_tests_fatal PROPERTIES
    PASS_REGULAR_EXPRESSION "\\[FATAL ERROR\\]: bye 42"
    FAIL_REGULAR_EXPRESSION "returned")
add_test(NAME base_tests_uncaught COMMAND base_tests uncaught)
set_tests_properties(base_tests_uncaught PROPERTIES
    PASS_REGULAR_EXPRESSION "Uncaught exception: boom 7"
    FAIL_REGULAR_EXPRESSION "returned")
add_test(NAME base_tests_uncaught_foreign COMMAND base_tests uncaught-foreign)
set_tests_properties(base_tests_uncaught_foreign PROPERTIES
    PASS_REGULAR_EXPRESSION "Uncaught exception of class 'Number'"
    FAIL_REGULAR_EXPRESSION "returned")

# On AArch64 Linux, libgcc's _Unwind_RaiseException() does not return
# _URC_END_OF_STACK for an uncaught exception (LLVM libunwind does), so
# libobjc2 aborts without calling the uncaught exception handler.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux"
   AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    set_tests_properties(base_tests_uncaught base_tests_uncaught_foreign
        PROPERTIES DISABLED TRUE)
endif()

if(WIN32)
    foreach(target playground base_tests)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_RUNTIME_DLLS:${target}>
            $<TARGET_FILE_DIR:${target}>
            COMMAND_EXPAND_LISTS)
    endforeach()
endif()
