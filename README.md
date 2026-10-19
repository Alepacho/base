# Base

[![CI](https://github.com/Alepacho/base/actions/workflows/ci.yml/badge.svg)](https://github.com/Alepacho/base/actions/workflows/ci.yml)

Base is a small collection of utilities for projects written in Objective-C.
Base does not require the Foundation framework: on macOS it only uses `NSObject` from the system `libobjc`,
on Windows and Linux it runs on top of [libobjc2](https://github.com/gnustep/libobjc2).

## Features

* Easy string manipulation (binary safe)
* Arrays and dictionaries
* Files
* Threads, mutexes, condition variables and selectors
* System related methods
* Exception handling

Base supports 64-bit platforms only (macOS, Linux and Windows). Sizes, counts and
indexes use `BaseSize`, which is `size_t`: print it with `%zu`.

## Memory management

Base uses manual retain/release (compile your code with `-fno-objc-arc`):

* `alloc`/`new` give you one reference, `retain` adds one, `release` drops one.
  Never call `dealloc` directly.
* `Array` takes over the reference passed to `push:`/`insert:` and releases its elements
  when they are removed or when the array is destroyed. `Dictionary` does the same with
  the key and the value passed to `set:forKey:`.
* Methods whose name starts with `copy` (`copy`, `copyDescription`, `copyKeys`...)
  return a new object that you own.
* `Thread` takes over the selector and the arguments passed to `create:`.
* A caught `Exception` belongs to the `@catch` block: `release` it when you are done.

## Errors

Base reports errors with exceptions and never ends the process on its own:

* Running out of memory throws an `Exception` whose message starts with `Out of memory`.
* An exception thrown by a `Thread`'s selector is rethrown by `join`. If nobody joins
  the thread, it is printed to stderr and released.
* `Selector` only calls methods it can call safely (object or void result, no argument
  or one object argument) and throws for any other one.
* Nothing is installed behind your back: call `[Exception installUncaughtHandler]` at
  startup if you want uncaught exceptions to print their message before the process aborts.

## Usage

Base requires the following dependencies:

```
    * clang   (at least 16)
    * lld     (for Windows and Linux only, see "Linker" below)
    * libobjc2 (at least 2.2, for Windows and Linux only; 2.3 is bundled as a submodule)
    * cmake   (at least 3.27)
    * ninja   (you can also use makefile)
```

> **Note:** libobjc2 before 2.2 corrupts arguments of the first message sent to a class on
> AArch64 (fixed upstream in gnustep/libobjc2#266).

The version is in `include/base/version.h` (`BASE_VERSION_STRING`, `BASE_VERSION`).

### In another CMake project

Either add Base as a subdirectory:

```cmake
add_subdirectory(vendor/base)
target_link_libraries(app PRIVATE base::base)
```

or install it and use `find_package()`:

```bash
cmake --install build --prefix <prefix>
```

```cmake
find_package(base 0.1 REQUIRED)  # with -DCMAKE_PREFIX_PATH=<prefix>
target_link_libraries(app PRIVATE base::base)
```

On Windows and Linux an installed Base looks for libobjc2 with `find_package(libobjc)`,
so libobjc2 has to be installed too (`cmake --install` in its build directory).
`test/package/` is a minimal project that does exactly this.

Options (the first two default to `ON` only when Base is the top-level project):

| Option             | Default | Meaning                                                    |
|--------------------|---------|------------------------------------------------------------|
| `BASE_BUILD_TESTS` | `ON`    | Build the unit tests and the playground                    |
| `BASE_INSTALL`     | `ON`    | Generate the install rules                                 |
| `BASE_SANITIZE`    | `OFF`   | Build with AddressSanitizer and UBSan (never exported)     |
| `BASE_WERROR`      | `OFF`   | Treat warnings in Base and its tests as errors (CI)        |
| `BASE_USE_LLD`     | `ON`    | Windows and Linux: link the targets using Base with lld    |

### Windows and Linux

You have to compile `libobjc2` first. Its configure step downloads
[robin-map](https://github.com/Tessil/robin-map) unless `tsl-robin-map` is already installed.

```bash
git submodule update --init --recursive
cd 3rdparty/libobjc2/
mkdir build && cd build
cmake .. -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DTESTS=OFF
ninja
```

And now you can make a `base` library.

```bash
cd ../../../
cmake -S . -B build -G Ninja -DCMAKE_C_COMPILER=clang
cmake --build build
```

Base finds libobjc2 in this order:

1. `-DBASE_OBJC2_BUILD_DIR=<build dir>` (with `-DBASE_OBJC2_DIR=<source dir>` when it is not
   the submodule): a libobjc2 build tree.
2. An `objc` target that already exists, e.g. libobjc2 added with `add_subdirectory()`.
3. An installed libobjc2 (`find_package(libobjc)`), add its prefix to `CMAKE_PREFIX_PATH`.
4. The submodule built in `3rdparty/libobjc2/build`, as above.

#### Linker

Targets that link Base are linked with lld (`-fuse-ld=lld`). A target can use another
linker by setting its `LINKER_TYPE` property (CMake 3.29+) or its `BASE_NO_LLD` property;
`-DBASE_USE_LLD=OFF` turns it off for the whole build.

### macOS

Notice that you need clang 16 or above to compile it!

```bash
cmake -S . -B build
cmake --build build
```

## Tests

```bash
cmake -S . -B build -DBASE_SANITIZE=ON   # optional: AddressSanitizer + UBSan
cmake --build build
ctest --test-dir build --output-on-failure
```

Unit tests live in `test/src/unit/`, one file per module. `System`'s `fatal:` and the uncaught
exception handler end the process, so they run as separate ctest tests that check the output.

CI (`.github/workflows/ci.yml`) runs them with `-DBASE_WERROR=ON` on macOS (Release,
ASan+UBSan, TSan), Linux x86_64 and arm64 (Release, ASan+UBSan) and Windows (Release, Debug),
and checks that an installed Base works with `find_package()`.

## Playground

If you want to test something, use the `playground` target (`test/src/main.m`). It is built into `bin/`.

## License

```
   Copyright 2023 Alepacho

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

Parts of `src/thread.m` are based on [TinyCThread](https://github.com/tinycthread/tinycthread)
(zlib license, see the notice in that file).
