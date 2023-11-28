#pragma once
#ifndef BASE_MAIN_H
#define BASE_MAIN_H

#define OS_WINDOWS NO
#define OS_MACOS   NO
#define OS_LINUX   NO

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"

#if defined(__APPLE__)
#define OS_MACOS YES
#elif defined(_WIN64) || defined(_WIN32)
#define OS_WINDOWS YES
#elif defined(__linux__)
#define OS_LINUX YES
#endif

#pragma clang diagnostic pop

// https://github.com/gnustep/libs-base
#include <objc/runtime.h>

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif

#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
@interface BaseObject {
	id isa;
}

+ (id)alloc;
- (void)dealloc;

- (id)init;

@end

#endif // BASE_MAIN_H
