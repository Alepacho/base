#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#if OS_WINDOWS
#define vs_string_length _vscprintf
#define vs_string_buffer vsprintf_s
#else
int vs_string_length(const char* format, va_list pargs) {
	int retval;
	va_list argcopy;
	va_copy(argcopy, pargs);
	retval = vsnprintf(NULL, 0, format, argcopy);
	va_end(argcopy);
	return retval;
}
#define vs_string_buffer vsnprintf
#endif

@implementation Exception

- (id)init {
	self = [super init];

	if (self) {
		self->message = [[String alloc] init];
	}

	return self;
}

- (id)initWithFormat:(const char*)fmt, ... {
	self = [self init];

	va_list args;
	va_start(args, fmt);
	const size_t length = vs_string_length(fmt, args) + 1;
	char* buffer = malloc(length * sizeof(char));
	if (buffer == nil) {
		[System fatal:"Unable to allocate memory for formatted string!"];
	}
	vs_string_buffer(buffer, length, fmt, args);
	[self->message appendBuffer:buffer];
	free(buffer);
	va_end(args);

	return self;
}

- (const char*)message {
	return [self->message buffer];
}

@end