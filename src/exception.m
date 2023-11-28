#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

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
	const size_t length = _vscprintf(fmt, args) + 1;
	char* buffer = malloc(length * sizeof(char));
	if (buffer == nil) {
		[System fatal:"Unable to allocate memory for formatted string!"];
	}
	vsprintf_s(buffer, length, fmt, args);
	[self->message appendBuffer:buffer];
	free(buffer);
	va_end(args);

	return self;
}

- (const char*)message {
	return [self->message buffer];
}

@end