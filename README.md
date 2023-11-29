# Base

Base is a small collection of utilities for projects written in Objective-C.
Base does not require Foundation framework (except for [macOS compatibility](https://github.com/Alepacho/base/blob/master/include/base/base.h)).

## Usage

Base requires follow dependencies:

```
    * clang (at least 16)
    * libobj2 (for Windows and Linux obly)
    * ninja (you can use makefile also)
```

### Windows:

Don't forget to specify your clang path.

```powershell
> git submodule update --init --recursive
> cd 3rdparty/libobjc2/
> mkdir build
> cd build
> cmake .. -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang
> ninja
> cd ../../../
> mkdir build
> cd build
> cmake ..
> make
```

### UNIX:

Linux and other UNIX-like systems are not tested yet.

```bash
$ I dunno...
```

### macOS:

Compilation is way simpler than on all systems above.

```bash
$ mkdir build && cd build
$ cmake ..
$ make
```
