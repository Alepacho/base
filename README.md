# Base

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
    * lld     (for Windows and Linux only)
    * libobjc2 (at least 2.2, for Windows and Linux only; 2.3 is bundled as a submodule)
    * cmake   (at least 3.27)
    * ninja   (you can also use makefile)
```

> **Note:** libobjc2 before 2.2 corrupts arguments of the first message sent to a class on
> AArch64 (fixed upstream in gnustep/libobjc2#266).

Base can be added to another CMake project with `add_subdirectory()`; link against the `base` target.
Tests are only built when Base is the top-level project (see the `BASE_BUILD_TESTS` option).

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

A libobjc2 built somewhere else can be used with `-DBASE_OBJC2_DIR=<source dir> -DBASE_OBJC2_BUILD_DIR=<build dir>`.

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
