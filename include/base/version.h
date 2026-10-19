#pragma once
#ifndef BASE_VERSION_H
#define BASE_VERSION_H

// CMakeLists.txt reads the version from here.
#define BASE_VERSION_MAJOR 0
#define BASE_VERSION_MINOR 1
#define BASE_VERSION_PATCH 0

#define BASE_VERSION_STRING "0.1.0"

// For comparisons: `#if BASE_VERSION >= BASE_MAKE_VERSION(0, 2, 0)`.
#define BASE_MAKE_VERSION(major, minor, patch)                                 \
	((major) * 10000 + (minor) * 100 + (patch))
#define BASE_VERSION                                                           \
	BASE_MAKE_VERSION(BASE_VERSION_MAJOR, BASE_VERSION_MINOR, BASE_VERSION_PATCH)

#endif // BASE_VERSION_H
