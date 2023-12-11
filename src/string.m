#include "base/string.h"
#include "base/system.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if OS_WINDOWS
#define string_copy strcpy_s
#define string_cat	strcat_s
#else
size_t string_copy(char* d, size_t n, char const* s) {
	return snprintf(d, n, "%s", s);
}
size_t string_cat(char* d, size_t n, char const* s) {
	return snprintf(d, n, "%s%s", d, s);
}
#endif

@implementation String

// @private

- (void)initBuffer:(const char*)buf {
	if (self->buffer != nil) {
		free(self->buffer);
		self->buffer = nil;
	}

	if (buf == nil) buf = "";

	const size_t length = strlen(buf);
	self->buffer = (char*)malloc((length + 1) * sizeof(char));
	if (self->buffer == nil) {
		[System fatal:"Unable to allocate memory for '%s' string!", buf];
	}
	// [System debug:"buf: '%s'", buf];
	// [System debug:"length: %zu", length];
	string_copy(self->buffer, length + 1, buf);
	// [System debug:"self->buffer: '%s'", self->buffer];
}

// @public

- (id)init {
	self = [super init];

	if (self) {
		// [System trace:"new?"];
		[self initBuffer:""];
	}

	return self;
}

- (id)initWithBuffer:(const char*)buf {
	self = [self init];

	[self initBuffer:buf];

	return self;
}

- (id)initWithString:(String*)str {
	self = [self init];

	[self initBuffer:[str buffer]];

	return self;
}

- (id)initWithFormat:(const char*)fmt, ... {
	self = [self init];
	self->buffer = nil;
	[System fatal:"Method '%s' is unemplemented!", "initWithFormat"];
	return self;
}

- (char*)buffer {
	return self->buffer;
}

- (void)dealloc {
	if (self->buffer != nil) {
		free(self->buffer);
		self->buffer = nil;
	}

	[super dealloc];
}

- (id)appendBuffer:(const char*)buf {
	if (self->buffer == nil) {
		[self initBuffer:buf];
		return self;
	}
	const size_t offset = strlen(self->buffer);
	size_t length = strlen(buf);
	if (length == 0) {
		[System fatal:"%s", "Attempt to append empty string!"];
	}

	size_t size = (offset + length + 1) * sizeof(char);
	self->buffer = (char*)realloc(self->buffer, size);

	// scpy(self->buffer + offset, length, buf);
	string_cat(self->buffer, size, buf);
	return self;
}

- (id)setBuffer:(const char*)buf {

	[self initBuffer:buf];

	return self;
}

- (id)setString:(String*)str {
	if (self->buffer != nil) {
		free(self->buffer);
		self->buffer = nil;
	}

	[self initBuffer:[str buffer]];

	return self;
}

- (size_t)length {
	return strlen(self->buffer);
}

- (BOOL)compareBuffer:(const char*)buf {
	// printf("'%s'\n", buf);
	// printf("'%s'\n", buffer);
	// printf("%i\n", (strncmp(buffer, buf, [self length]) == 0));
	return (strncmp(buffer, buf, [self length]) == 0) ? YES : NO;
}

@end