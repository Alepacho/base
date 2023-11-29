#import "base/base.h"

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

static void _baseUncaughtExceptionHandler(NSException* exception) {
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

- (Class)class {
	return [self class];
}

+ (Class)class {
	return self;
}

#if OS_MACOS

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

- (id)autorelease {
	return [super autorelease];
}

- (id)retain {
	return [super retain];
}

- (void)release {
	[super release];
}

+ (BOOL)respondsToSelector:(SEL)selector {
	return [super respondsToSelector:selector];
}

+ (BOOL)instancesRespondToSelector:(SEL)selector {
	return [super instancesRespondToSelector:selector];
}

#else

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (void)dealloc {
	object_dispose(self);
}

- (id)init {
	return self;
}

- (id)autorelease {
	return objc_autorelease(self);
}
- (id)retain {
	return objc_retain(self);
}
- (void)release {
	objc_release(self);
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
