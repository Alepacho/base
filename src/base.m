#import "base/base.h"

#if OS_MACOS

#else
#import <objc/objc-arc.h>
#endif

#include <objc/objc-exception.h>
#include <stdio.h>

#if OS_MACOS

#elif OS_WINDOWS
#include <Windows.h>
LONG WINAPI
_baseUnhandledExceptionFilter(struct _EXCEPTION_POINTERS* exceptionInfo) {
	printf("windows!\n");
	exit(1);
}
#elif OS_LINUX
#else
#error "OS not supported"
#endif

static void _baseUncaughtExceptionHandler(id exception) {
	printf("uncaught exception!\n");
	exit(1);
}

void _mainBase(void) {
#if OS_WINDOWS
	SetUnhandledExceptionFilter(&_baseUnhandledExceptionFilter);
#endif
	objc_setUncaughtExceptionHandler(_baseUncaughtExceptionHandler);
}

@implementation BaseObject

// - (Class)class {
// 	return [self class];
// }

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

#if OS_MACOS

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

// + (BOOL)respondsToSelector:(SEL)selector {
// 	return [super respondsToSelector:selector];
// }

// + (BOOL)instancesRespondToSelector:(SEL)selector {
// 	return [super instancesRespondToSelector:selector];
// }

#else

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (void)dealloc {
	object_dispose(self);
}

- (id)autorelease {
	return objc_autorelease(self);
}
- (id)retain {
	refcount++;
	return self; // objc_retain(self);
}
- (void)release {
	if (refcount == 0)
		[self dealloc]; // objc_release(self);
	else
		refcount--;
}

// + (BOOL)respondsToSelector:(SEL)selector {
// 	return class_respondsToSelector(object_getClass(self), selector);
// }

// + (BOOL)instancesRespondToSelector:(SEL)selector {
// 	return class_respondsToSelector(self, selector);
// }

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
