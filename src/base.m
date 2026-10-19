#import "base/base.h"

#if !OS_MACOS
#import <objc/objc-arc.h>
#include <stdatomic.h>
#endif

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

// - (id)copy {
// 	return [self retain];
// }

+ (BOOL)isMemberOfClass:(Class)aClass {
	return (self == aClass) ? YES : NO;
}

- (BOOL)isMemberOfClass:(Class)aClass {
	return ([self class] == aClass) ? YES : NO;
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

@implementation Number

- (id)init {
	self = [super init];
	if (self) {
		self->value = 0;
	}
	return self;
}

- (id)initValue:(Size)newValue {
	self = [super init];
	if (self) {
		self->value = newValue;
	}
	return self;
}

- (Size)value {
	return value;
}
- (id)set:(Size)newValue {
	value = newValue;
	return self;
}

@end
