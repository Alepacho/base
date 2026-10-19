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

#include <stddef.h>

// Sizes, counts and indexes. Base supports 64-bit platforms only.
typedef size_t BaseSize;

_Static_assert(sizeof(void*) == 8 && sizeof(BaseSize) == 8,
			   "base supports 64-bit platforms only");

// Returned by lookup methods when nothing was found.
#define BASE_NOT_FOUND ((BaseSize) - 1)

@class String;

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

// Exact class check, subclasses do not count.
+ (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;

// The class itself or one of its subclasses.
+ (BOOL)isSubclassOfClass:(Class)aClass;
- (BOOL)isKindOfClass:(Class)aClass;

// Sent to a class object, `respondsToSelector:` checks class methods.
+ (BOOL)instancesRespondToSelector:(SEL)selector;
- (BOOL)respondsToSelector:(SEL)selector;

// Equality used by Dictionary keys and Array lookups. By default an object
// is only equal to itself. Equal objects must have the same hash.
- (BOOL)isEqual:(id)object;
- (BaseSize)hash;

// Returns a new object equal to this one, owned by the caller.
// Throws an Exception for classes that can not be copied (the default).
- (id)copy;

// Returns a new String describing the object, owned by the caller.
// `<ClassName: 0x...>` by default.
- (String*)copyDescription;

@end

#pragma clang diagnostic pop

typedef enum {
	BASE_NUMBER_UNSIGNED,
	BASE_NUMBER_SIGNED,
	BASE_NUMBER_REAL,
} BaseNumberKind;

// An unsigned, signed or floating point number.
//
// Every getter converts the stored value: signed and unsigned integers wrap
// around, reals are truncated towards zero and clamped to the range of the
// result (NaN gives 0).
//
// Numbers are equal when they have the same kind and value.
@interface Number : BaseObject {
	BaseNumberKind kind;
	union {
		BaseSize u;
		long long i;
		double d;
	} storage;
}

// 0, unsigned.
- (id)init;
- (id)initValue:(BaseSize)newValue;
- (id)initWithInteger:(long long)newValue;
- (id)initWithReal:(double)newValue;

- (BaseNumberKind)kind;

- (BaseSize)value;
- (long long)integer;
- (double)real;

// Each setter also changes the kind.
- (id)set:(BaseSize)newValue;
- (id)setInteger:(long long)newValue;
- (id)setReal:(double)newValue;

@end

#endif // BASE_MAIN_H
