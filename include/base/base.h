#pragma once
#ifndef BASE_MAIN_H
#define BASE_MAIN_H

#define OS_WINDOWS 0
#define OS_MACOS   0
#define OS_LINUX   0

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"

#if defined(__APPLE__)
#define OS_MACOS 1
#import <Foundation/Foundation.h>
#elif defined(_WIN64) || defined(_WIN32)
#define OS_WINDOWS 1
#elif defined(__linux__)
#define OS_LINUX 1
#else
#error "Unknown OS"
#endif

void _baseUncaughtExceptionHandler(id exception);
void _mainBase(void) __attribute__((constructor));

#pragma clang diagnostic pop

// https://github.com/gnustep/libs-base
#include <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-root-class"

#if OS_MACOS
@interface BaseObject : NSObject
#else

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
@interface BaseObject {
	id isa;
}
#endif

+ (id)alloc;
- (void)dealloc;

- (id)init;
+ (id)new;

+ (BOOL)respondsToSelector:(SEL)selector;
+ (BOOL)instancesRespondToSelector:(SEL)selector;

@end

#pragma clang diagnostic pop

#endif // BASE_MAIN_H
