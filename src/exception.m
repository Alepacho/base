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
extern int vs_string_length(const char* format, va_list pargs);
#define vs_string_buffer vsnprintf
#endif

@implementation Exception

- (id)init {
	self = [super init];

	if (self) {
		self->message = [String new];
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

- (id)initWithString:(String*)str {
	self = [self init];

	[self->message setString:str];

	return self;
}

- (const char*)message {
	if ([self->message length] == 0) return "Unknown error";
	return [self->message buffer];
}

@end