#import "base/base.h"

#include </objc/objc-exception.h>
#include <stdio.h>

#if OS_WINDOWS
#include <Windows.h>

LONG WINAPI
_baseUnhandledExceptionFilter(struct _EXCEPTION_POINTERS* exceptionInfo) {
	printf("windows!\n");
	exit(0);
}

#endif

void _mainBase(void) {
#if OS_MACOS

#else

#if OS_WINDOWS
	SetUnhandledExceptionFilter(&_baseUnhandledExceptionFilter);
#endif

	objc_setUncaughtExceptionHandler(_baseUncaughtExceptionHandler);
#endif
}

void _baseUncaughtExceptionHandler(id exception) {
	printf("uncaught exception!\n");
}

@implementation BaseObject

#if OS_MACOS

+ (Class)class {
	return [super class];
}

+ (id)alloc {
	return [super alloc];
}

- (void)dealloc {
	[super dealloc];
}

- (id)init {
	return [super init];
}

+ (id)new {
	return [super new];
}

+ (BOOL)respondsToSelector:(SEL)selector {
	return [super respondsToSelector:selector];
}

+ (BOOL)instancesRespondToSelector:(SEL)selector {
	return [super instancesRespondToSelector:selector];
}

#else

+ (Class)class {
	return self;
}

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (void)dealloc {
	object_dispose(self);
}

- (id)init {
	return self;
}

+ (id)new {
	return [[self alloc] init];
}

+ (BOOL)respondsToSelector:(SEL)selector {
	return class_respondsToSelector(object_getClass(self), selector);
}

+ (BOOL)instancesRespondToSelector:(SEL)selector {
	return class_respondsToSelector(self, selector);
}

#endif
@end
