#pragma once

#ifndef BASE_MAIN_H
#define BASE_MAIN_H

#define OS_WINDOWS 0
#define OS_MACOS   0
#define OS_LINUX   0

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"

#include "os.h"

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
#endif // __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif // __has_attribute(objc_root_class)
@interface BaseObject {
	id isa;
	int refcount;
}
#endif // OS_MACOS

+ (Class)class;
- (Class)class;

+ (id)alloc;
- (void)dealloc;

- (id)init;
+ (id)new;

- (id)autorelease;
- (id)retain;
- (void)release;

// - (id)copy;

// TODO: should I keep it?
// + (BOOL)respondsToSelector:(SEL)selector;
// + (BOOL)instancesRespondToSelector:(SEL)selector;

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

@interface Number : BaseObject {
	Size value;
}

- (id)init;
- (id)initValue:(Size)newValue;

- (Size)value;
- (id)set:(Size)newValue;

@end

#endif // BASE_MAIN_H
