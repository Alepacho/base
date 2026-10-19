#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"
#include "internal.h"

#include <objc/objc-exception.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static BOOL baseIsKindOfClass(Class s, Class a) {
	while (s != Nil) {
		if (s == a) return YES;
		s = class_getSuperclass(s);
	}
	return NO;
}

void baseReportException(const char* prefix, id exception) {
	if (exception != nil
		&& baseIsKindOfClass(object_getClass(exception), [Exception class])) {
		fprintf(stderr, "%s: %s\n", prefix, [(Exception*)exception message]);
	} else {
		fprintf(stderr,
				"%s of class '%s'\n",
				prefix,
				exception ? class_getName(object_getClass(exception)) : "nil");
	}
	fflush(stderr);
}

void baseReleaseException(id exception) {
	if (exception != nil
		&& class_respondsToSelector(object_getClass(exception),
									@selector(release))) {
		[exception release];
	}
}

void baseThrowOutOfMemory(const char* fmt, ...) {
	// Creating the Exception allocates too: if that fails as well, give up.
	static _Thread_local BOOL throwing = NO;
	if (throwing) [System fatal:"Out of memory!"];
	throwing = YES;

	va_list args;
	va_start(args, fmt);
	String* what = [[String alloc] initWithFormat:fmt arguments:args];
	va_end(args);
	Exception* ex =
		[[Exception alloc] initWithFormat:"Out of memory: %s", [what buffer]];
	[what release];

	throwing = NO;
	if (ex == nil) [System fatal:"Out of memory!"];
	@throw ex;
}

static void baseUncaughtExceptionHandler(id exception) {
	baseReportException("Uncaught exception", exception);
	// abort() instead of exit() so the debugger / crash reporter still sees it.
	abort();
}

@implementation Exception

- (id)init {
	self = [super init];

	if (self) {
		@try {
			self->message = [String new];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}

	return self;
}

- (id)initWithFormat:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	self = [self initWithFormat:fmt arguments:args];
	va_end(args);

	return self;
}

- (id)initWithFormat:(const char*)fmt arguments:(va_list)args {
	self = [self init];

	if (self) {
		@try {
			[self->message setFormat:fmt arguments:args];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}

	return self;
}

- (id)initWithString:(String*)str {
	self = [self init];

	if (self) {
		@try {
			[self->message setString:str];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}

	return self;
}

- (void)dealloc {
	[self->message release];
	self->message = nil;

	[super dealloc];
}

- (const char*)message {
	if ([self->message length] == 0) return "Unknown error";
	return [self->message buffer];
}

+ (void)installUncaughtHandler {
	objc_setUncaughtExceptionHandler(baseUncaughtExceptionHandler);
}

@end
