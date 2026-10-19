#import "base/base.h"
#import "base/exception.h"
#import "base/string.h"
#import "internal.h"

#include <limits.h>
#include <stdint.h>
#include <string.h>

#if !OS_MACOS
#import <objc/objc-arc.h>
#include <stdatomic.h>
#endif

void baseAppendDescription(String* str, id object) {
	if (object == nil
		|| !class_respondsToSelector(object_getClass(object),
									 @selector(copyDescription))) {
		[str appendFormat:"<%s: %p>",
						  object ? class_getName(object_getClass(object))
								 : "nil",
						  (void*)object];
		return;
	}

	String* description = [object copyDescription];
	@try {
		[str appendBuffer:[description buffer] length:[description length]];
	} @catch (id ex) {
		[description release];
		@throw;
	}
	[description release];
}

@implementation BaseObject

+ (Class)class {
	return self;
}

- (id)init {
	return self;
}

+ (id)new {
	return [[self alloc] init];
}

+ (BOOL)isMemberOfClass:(Class)aClass {
	return (self == aClass) ? YES : NO;
}

- (BOOL)isMemberOfClass:(Class)aClass {
	return ([self class] == aClass) ? YES : NO;
}

static BOOL baseIsSubclass(Class cls, Class aClass) {
	for (; cls != Nil; cls = class_getSuperclass(cls)) {
		if (cls == aClass) return YES;
	}
	return NO;
}

+ (BOOL)isSubclassOfClass:(Class)aClass {
	return baseIsSubclass(self, aClass);
}

- (BOOL)isKindOfClass:(Class)aClass {
	// For class objects this walks the metaclasses, as in NSObject.
	return baseIsSubclass(object_getClass(self), aClass);
}

+ (BOOL)instancesRespondToSelector:(SEL)selector {
	if (selector == NULL) return NO;
	return class_respondsToSelector(self, selector) ? YES : NO;
}

- (BOOL)respondsToSelector:(SEL)selector {
	if (selector == NULL) return NO;
	return class_respondsToSelector(object_getClass(self), selector) ? YES : NO;
}

- (BOOL)isEqual:(id)object {
	return (self == object) ? YES : NO;
}

- (BaseSize)hash {
	return (BaseSize)(uintptr_t)self;
}

- (id)copy {
	@throw
		[[Exception alloc] initWithFormat:"Instances of '%s' can not be copied",
										  class_getName(object_getClass(self))];
}

- (String*)copyDescription {
	return [[String alloc] initWithFormat:"<%s: %p>",
										  class_getName(object_getClass(self)),
										  (void*)self];
}

#if OS_MACOS

- (Class)class {
	return [super class];
}

+ (id)alloc {
	return [super alloc];
}

- (void)dealloc {
	[super dealloc];
}

- (id)autorelease {
	return [super autorelease];
}

- (id)retain {
	return [super retain];
}

- (void)release {
	[super release];
}

#else

- (Class)class {
	return object_getClass(self);
}

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (void)dealloc {
	object_dispose(self);
}

- (id)autorelease {
	// BaseObject implements its own retain/release, so libobjc2 can only
	// keep it in its own (ARC) autorelease pool. That pool mode is switched on
	// by the first objc_autoreleasePoolPush(); without it objc_autorelease()
	// would send -autorelease back here and recurse forever.
	static atomic_flag poolReady = ATOMIC_FLAG_INIT;
	if (!atomic_flag_test_and_set(&poolReady)) {
		objc_autoreleasePoolPop(objc_autoreleasePoolPush());
	}
	return objc_autorelease(self);
}

- (id)retain {
	__atomic_add_fetch(&refcount, 1, __ATOMIC_RELAXED);
	return self;
}

- (void)release {
	// refcount counts *extra* references, 0 means a single owner.
	if (__atomic_fetch_sub(&refcount, 1, __ATOMIC_ACQ_REL) == 0) {
		[self dealloc];
	}
}

#endif
@end

// Conversions that are undefined behaviour in C when out of range.
static long long baseRealToInteger(double d) {
	if (d != d) return 0;
	if (d >= 9223372036854775808.0) return LLONG_MAX; // 2^63
	if (d <= -9223372036854775808.0) return LLONG_MIN;
	return (long long)d;
}

static BaseSize baseRealToUnsigned(double d) {
	if (d != d || d <= 0) return 0;
	if (d >= 18446744073709551616.0) return SIZE_MAX; // 2^64
	return (BaseSize)d;
}

@implementation Number

- (id)init {
	return [self initValue:0];
}

- (id)initValue:(BaseSize)newValue {
	self = [super init];
	if (self) {
		[self set:newValue];
	}
	return self;
}

- (id)initWithInteger:(long long)newValue {
	self = [super init];
	if (self) {
		[self setInteger:newValue];
	}
	return self;
}

- (id)initWithReal:(double)newValue {
	self = [super init];
	if (self) {
		[self setReal:newValue];
	}
	return self;
}

- (BaseNumberKind)kind {
	return kind;
}

- (BaseSize)value {
	switch (kind) {
		case BASE_NUMBER_SIGNED:
			return (BaseSize)storage.i;
		case BASE_NUMBER_REAL:
			return baseRealToUnsigned(storage.d);
		default:
			return storage.u;
	}
}

- (long long)integer {
	switch (kind) {
		case BASE_NUMBER_UNSIGNED:
			// wraps around, like the conversion of any two's complement CPU
			if (storage.u <= (BaseSize)LLONG_MAX) return (long long)storage.u;
			return (long long)(storage.u - (BaseSize)LLONG_MAX - 1) + LLONG_MIN;
		case BASE_NUMBER_REAL:
			return baseRealToInteger(storage.d);
		default:
			return storage.i;
	}
}

- (double)real {
	switch (kind) {
		case BASE_NUMBER_UNSIGNED:
			return (double)storage.u;
		case BASE_NUMBER_SIGNED:
			return (double)storage.i;
		default:
			return storage.d;
	}
}

- (id)set:(BaseSize)newValue {
	kind = BASE_NUMBER_UNSIGNED;
	storage.u = newValue;
	return self;
}

- (id)setInteger:(long long)newValue {
	kind = BASE_NUMBER_SIGNED;
	storage.i = newValue;
	return self;
}

- (id)setReal:(double)newValue {
	kind = BASE_NUMBER_REAL;
	storage.d = newValue;
	return self;
}

- (BOOL)isEqual:(id)object {
	if (self == object) return YES;
	if (object == nil || ![object isKindOfClass:[Number class]]) return NO;

	Number* other = object;
	if (kind != [other kind]) return NO;
	switch (kind) {
		case BASE_NUMBER_SIGNED:
			return storage.i == [other integer];
		case BASE_NUMBER_REAL:
			return storage.d == [other real];
		default:
			return storage.u == [other value];
	}
}

- (BaseSize)hash {
	BaseSize bits = storage.u;
	if (kind == BASE_NUMBER_REAL) {
		// 0.0 == -0.0, so they must hash the same
		const double d = storage.d == 0 ? 0.0 : storage.d;
		memcpy(&bits, &d, sizeof(bits));
	}
	return bits ^ ((BaseSize)kind << 62);
}

- (id)copy {
	Number* n = [[[self class] alloc] init];
	n->kind = kind;
	n->storage = storage;
	return n;
}

- (String*)copyDescription {
	switch (kind) {
		case BASE_NUMBER_SIGNED:
			return [[String alloc] initWithFormat:"%lld", storage.i];
		case BASE_NUMBER_REAL:
			return [[String alloc] initWithFormat:"%g", storage.d];
		default:
			return [[String alloc] initWithFormat:"%zu", storage.u];
	}
}

@end
