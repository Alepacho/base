#include "base/string.h"
#include "base/exception.h"
#include "internal.h"

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Formats into a new heap buffer that the caller must free().
BASE_FORMAT(1, 0)
static char* baseVFormat(const char* fmt, va_list args, size_t* outLength) {
	va_list copy;
	va_copy(copy, args);
	const int length = vsnprintf(NULL, 0, fmt, copy);
	va_end(copy);

	if (length < 0)
		@throw [[Exception alloc]
			initWithFormat:"Invalid format string '%s'!", fmt];

	char* buf = malloc((size_t)length + 1);
	if (buf == NULL)
		baseThrowOutOfMemory("unable to allocate %lld bytes for a formatted "
							 "string!",
							 (long long)length + 1);
	vsnprintf(buf, (size_t)length + 1, fmt, args);
	*outLength = (size_t)length;
	return buf;
}

@implementation String

// @private

// Makes room for `needed` bytes, the terminating NUL included.
// The contents are kept, even when it throws.
- (void)reserve:(size_t)needed {
	if (needed <= self->capacity) return;

	size_t newCapacity = self->capacity < 16 ? 16 : self->capacity;
	while (newCapacity < needed) {
		newCapacity = (newCapacity > SIZE_MAX / 2) ? needed : newCapacity * 2;
	}

	char* newBuffer = realloc(self->buffer, newCapacity);
	if (newBuffer == NULL)
		baseThrowOutOfMemory("unable to allocate %zu bytes for a string!",
							 newCapacity);
	self->buffer = newBuffer;
	self->capacity = newCapacity;
}

// Writes `len` bytes of `buf` at `offset` and ends the string there.
// `buf` may point into our own buffer, which reserve: can move.
- (void)write:(const char*)buf length:(size_t)len at:(size_t)offset {
	if (buf == NULL) len = 0;
	if (len > SIZE_MAX - 1 - offset)
		baseThrowOutOfMemory("a string can not be longer than %zu bytes!",
							 (size_t)SIZE_MAX - 1);

	const uintptr_t start = (uintptr_t)self->buffer;
	const uintptr_t address = (uintptr_t)buf;
	const BOOL isInner = self->buffer != NULL && address >= start
						 && address <= start + self->length;
	const size_t innerOffset = isInner ? (size_t)(address - start) : 0;

	[self reserve:offset + len + 1];
	if (isInner) buf = self->buffer + innerOffset;

	if (len > 0) memmove(self->buffer + offset, buf, len);
	self->length = offset + len;
	self->buffer[self->length] = '\0';
}

// Reallocates the buffer to exactly `newCapacity` bytes (at least
// `length + 1`). Keeps the old one if the system can not do it.
- (void)fit:(size_t)newCapacity {
	if (newCapacity >= self->capacity) return;
	char* newBuffer = realloc(self->buffer, newCapacity);
	if (newBuffer == NULL) return;
	self->buffer = newBuffer;
	self->capacity = newCapacity;
}

// Takes over `buf`, a heap buffer of `len + 1` bytes ending with a NUL.
- (void)adopt:(char*)buf length:(size_t)len {
	free(self->buffer);
	self->buffer = buf;
	self->length = len;
	self->capacity = len + 1;
}

// @public

- (id)init {
	self = [super init];

	if (self) {
		self->buffer = NULL;
		self->length = 0;
		self->capacity = 0;
		@try {
			[self reserve:1];
		} @catch (id ex) {
			[self release];
			@throw;
		}
		self->buffer[0] = '\0';
	}

	return self;
}

- (id)initWithBuffer:(const char*)buf {
	return [self initWithBuffer:buf length:buf ? strlen(buf) : 0];
}

- (id)initWithBuffer:(const char*)buf length:(size_t)len {
	self = [self init];

	if (self) {
		@try {
			[self write:buf length:len at:0];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}

	return self;
}

- (id)initWithString:(String*)str {
	return [self initWithBuffer:[str buffer] length:[str length]];
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
			[self setFormat:fmt arguments:args];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}

	return self;
}

- (void)clear {
	self->length = 0;
	self->buffer[0] = '\0';
	// Small buffers are kept: clearing and refilling a string is common.
	if (self->capacity > 4096) [self fit:16];
}

- (id)shrink {
	[self fit:self->length + 1];
	return self;
}

- (char*)buffer {
	return self->buffer;
}

- (void)dealloc {
	free(self->buffer);
	self->buffer = NULL;

	[super dealloc];
}

- (id)appendBuffer:(const char*)buf {
	return [self appendBuffer:buf length:buf ? strlen(buf) : 0];
}

- (id)appendBuffer:(const char*)buf length:(size_t)len {
	if (buf == NULL || len == 0) return self;
	[self write:buf length:len at:self->length];
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
	size_t len = 0;
	char* buf = baseVFormat(fmt, args, &len);
	@try {
		[self appendBuffer:buf length:len];
	} @catch (id ex) {
		free(buf);
		@throw;
	}
	free(buf);

	return self;
}

- (id)appendChar:(const char)ch {
	if (ch == '\0') return self;
	[self write:&ch length:1 at:self->length];
	return self;
}

- (id)setBuffer:(const char*)buf {
	return [self setBuffer:buf length:buf ? strlen(buf) : 0];
}

- (id)setBuffer:(const char*)buf length:(size_t)len {
	[self write:buf length:len at:0];
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
	size_t len = 0;
	char* buf = baseVFormat(fmt, args, &len);
	[self adopt:buf length:len];

	return self;
}

- (id)setString:(String*)str {
	return [self setBuffer:[str buffer] length:[str length]];
}

- (size_t)length {
	return self->length;
}

- (BOOL)compareBuffer:(const char*)buf {
	if (buf == NULL) return NO;
	return (strlen(buf) == self->length
			&& memcmp(self->buffer, buf, self->length) == 0)
			   ? YES
			   : NO;
}

+ (BOOL)compareBuffer:(const char*)buf withBuffer:(const char*)buf2 {
	if (buf == NULL || buf2 == NULL) return NO;
	return strcmp(buf, buf2) == 0 ? YES : NO;
}

- (BOOL)isEqual:(id)object {
	if (self == object) return YES;
	if (object == nil || ![object isKindOfClass:[String class]]) return NO;

	String* other = object;
	return ([other length] == self->length
			&& memcmp(self->buffer, [other buffer], self->length) == 0)
			   ? YES
			   : NO;
}

- (BaseSize)hash {
	// FNV-1a
	BaseSize h = 14695981039346656037ULL;
	for (size_t i = 0; i < self->length; i++) {
		h ^= (unsigned char)self->buffer[i];
		h *= 1099511628211ULL;
	}
	return h;
}

- (id)copy {
	return [[[self class] alloc] initWithString:self];
}

- (String*)copyDescription {
	return [[String alloc] initWithString:self];
}

@end
