# Base

Base is a small collection of utilities for projects written in Objective-C.
Base does not require Foundation framework (except for [macOS compatibility](https://github.com/Alepacho/base/blob/master/include/base/base.h)).

## Features

* Easy string manipulation
* Simple Arrays
* System related methods
* Exception handling

## Usage

Base requires the following dependencies:

```
    * clang   (at least 16)
    * libobj2 (for Windows and Linux only)
    * ninja   (you can also use makefile)
```

### Windows:

You have to compile `libobjc2` first.

```powershell
> git submodule update --init --recursive
> cd 3rdparty/libobjc2/
> mkdir build
> cd build
> cmake .. -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang
> ninja
```

And now you can make a `base` library.

```powershell
> cd ../../../
> mkdir build
> cd build
> cmake .. -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang
> ninja
```

### UNIX:

Linux and other UNIX-like systems are not tested yet.

```bash
$ I dunno...
```

### macOS:

Compilation is way simpler than on all systems above.
Notice that you need clang 16 or above to compile it!

```bash
$ mkdir build && cd build
$ cmake ..
$ make
```

##

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
