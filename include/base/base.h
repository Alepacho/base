#pragma once

#ifndef BASE_MAIN_H
#define BASE_MAIN_H

#include "os.h"

#if OS_MACOS
// NSObject lives in libobjc itself, Foundation is not required.
#include <objc/NSObject.h>
#endif

// https://github.com/gnustep/libs-base
#include <objc/runtime.h>

// Lets the compiler check printf-style arguments of variadic methods.
// `f` is the index of the format argument, `a` of the first variadic one
// (0 for methods that take a `va_list`).
#define BASE_FORMAT(f, a) __attribute__((format(printf, f, a)))

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-root-class"

#if OS_MACOS
@interface BaseObject : NSObject
#else

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif // __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif // __has_attribute(objc_root_class)
@interface BaseObject {
	Class isa;
	int refcount;
}
#endif // OS_MACOS

+ (Class)class;
- (Class)class;

+ (id)alloc;
- (void)dealloc;

- (id)init;
+ (id)new;

// Memory management follows the manual retain/release rules:
// `alloc`/`new` give you one reference, `retain` adds one, `release` drops
// one and destroys the object when the last one is gone.
// Never call `dealloc` directly, use `release` instead.
- (id)autorelease;
- (id)retain;
- (void)release;

// - (id)copy;

// TODO: add selector methods
// + (BOOL)respondsToSelector:(SEL)selector;
// + (BOOL)instancesRespondToSelector:(SEL)selector;
// - (BOOL)performSelector:(SEL)selector;
// - (BOOL)performSelector:(SEL)selector withObject:(id)object;

// + (BOOL)isKindOfClass:(Class)aClass;
// - (BOOL)isKindOfClass:(Class)aClass;

+ (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;

@end

#pragma clang diagnostic pop

#if OS_MACOS
#define Size BaseSize
#endif

typedef unsigned long long Size;

// Returned by lookup methods when nothing was found.
#define BASE_NOT_FOUND ((Size) - 1)

@interface Number : BaseObject {
	Size value;
}

- (id)init;
- (id)initValue:(Size)newValue;

- (Size)value;
- (id)set:(Size)newValue;

@end

#endif // BASE_MAIN_H
