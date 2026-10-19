# Checks that an installed base can be used with find_package():
#
#   cmake --install <base build dir> --prefix <prefix>
#   cmake -S test/package -B <dir> -DCMAKE_PREFIX_PATH=<prefix>
#   cmake --build <dir> && ctest --test-dir <dir>
cmake_minimum_required(VERSION 3.27)
project(base_package_test LANGUAGES C)

find_package(base 0.1 REQUIRED)

add_executable(package_test main.m)
target_link_libraries(package_test PRIVATE base::base)
target_compile_options(package_test PRIVATE -fno-objc-arc -Wall -Werror)

if(WIN32)
    add_custom_command(TARGET package_test POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_RUNTIME_DLLS:package_test> $<TARGET_FILE_DIR:package_test>
        COMMAND_EXPAND_LISTS)
endif()

enable_testing()
add_test(NAME package_test COMMAND package_test)
set_tests_properties(package_test PROPERTIES
    PASS_REGULAR_EXPRESSION "base [0-9]+\\.[0-9]+\\.[0-9]+: \\{answer: 42\\}")
