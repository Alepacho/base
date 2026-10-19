#include "base/string.h"
#include "base/exception.h"
#include "base/system.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Formats into a new heap buffer that the caller must free().
BASE_FORMAT(1, 0) static char* baseVFormat(const char* fmt, va_list args) {
	va_list copy;
	va_copy(copy, args);
	const int length = vsnprintf(NULL, 0, fmt, copy);
	va_end(copy);

	if (length < 0)
		@throw [[Exception alloc]
			initWithFormat:"Invalid format string '%s'!", fmt];

	char* buf = malloc((size_t)length + 1);
	if (buf == NULL) {
		[System fatal:"Unable to allocate memory for formatted string!"];
	}
	vsnprintf(buf, (size_t)length + 1, fmt, args);
	return buf;
}

@implementation String

// @private

- (void)initBuffer:(const char*)buf {
	if (buf == nil) buf = "";

	// Copy first and free afterwards: `buf` may point into our own buffer.
	const size_t length = strlen(buf);
	char* newBuffer = malloc(length + 1);
	if (newBuffer == nil) {
		[System fatal:"Unable to allocate memory for a %zu bytes string!",
					  length + 1];
	}
	memcpy(newBuffer, buf, length + 1);

	free(self->buffer);
	self->buffer = newBuffer;
}

// @public

- (id)init {
	self = [super init];

	if (self) {
		[self initBuffer:""];
	}

	return self;
}

- (id)initWithBuffer:(const char*)buf {
	self = [self init];

	if (self) {
		[self initBuffer:buf];
	}

	return self;
}

- (id)initWithString:(String*)str {
	self = [self init];

	if (self) {
		[self initBuffer:[str buffer]];
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
		[self setFormat:fmt arguments:args];
	}

	return self;
}

- (void)clear {
	[self initBuffer:""];
}

- (char*)buffer {
	return self->buffer;
}

- (void)dealloc {
	free(self->buffer);
	self->buffer = nil;

	[super dealloc];
}

- (id)appendBuffer:(const char*)buf {
	if (buf == nil || buf[0] == '\0') return self;
	if (self->buffer == nil) {
		[self initBuffer:buf];
		return self;
	}

	const size_t offset = strlen(self->buffer);
	const size_t length = strlen(buf);

	// `buf` may point into our own buffer which realloc() can move.
	const BOOL isInner = buf >= self->buffer && buf <= self->buffer + offset;
	const size_t innerOffset = isInner ? (size_t)(buf - self->buffer) : 0;

	char* newBuffer = realloc(self->buffer, offset + length + 1);
	if (newBuffer == nil) {
		[System fatal:"Unable to allocate memory for a %zu bytes string!",
					  offset + length + 1];
	}
	self->buffer = newBuffer;
	if (isInner) buf = self->buffer + innerOffset;

	memmove(self->buffer + offset, buf, length);
	self->buffer[offset + length] = '\0';
	return self;
}

- (id)appendFormat:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	[self appendFormat:fmt arguments:args];
	va_end(args);

	return self;
}

- (id)appendFormat:(const char*)fmt arguments:(va_list)args {
	char* buf = baseVFormat(fmt, args);
	[self appendBuffer:buf];
	free(buf);

	return self;
}

- (id)appendChar:(const char)ch {
	const char str[2] = { ch, '\0' };
	[self appendBuffer:str];
	return self;
}

- (id)setBuffer:(const char*)buf {
	[self initBuffer:buf];

	return self;
}

- (id)setFormat:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	[self setFormat:fmt arguments:args];
	va_end(args);

	return self;
}

- (id)setFormat:(const char*)fmt arguments:(va_list)args {
	char* buf = baseVFormat(fmt, args);
	[self initBuffer:buf];
	free(buf);

	return self;
}

- (id)setString:(String*)str {
	[self initBuffer:[str buffer]];
	return self;
}

- (size_t)length {
	return strlen(self->buffer);
}

- (BOOL)compareBuffer:(const char*)buf {
	if (buf == nil) return NO;
	return (strcmp(self->buffer, buf) == 0) ? YES : NO;
}

@end
