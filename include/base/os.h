#pragma once
#ifndef BASE_OS_H
#define BASE_OS_H

#if defined(__APPLE__)
#define OS_WINDOWS 0
#define OS_MACOS   1
#define OS_LINUX   0
#elif defined(_WIN64) || defined(_WIN32)
#define OS_WINDOWS 1
#define OS_MACOS   0
#define OS_LINUX   0
#elif defined(__linux__)
#define OS_WINDOWS 0
#define OS_MACOS   0
#define OS_LINUX   1
#else
#error "Unknown OS"
#endif

#endif // BASE_OS_H
