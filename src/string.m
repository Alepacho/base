#include "base/string.h"
#include "base/system.h"
#include <stdlib.h>
#include <string.h>

#define string_copy strcpy_s
#define string_cat	strcat_s

@implementation String

// @private

- (void)initBuffer:(const char*)buf {
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
		self->buffer = nil;
	}

	return self;
}

- (id)initWithBuffer:(const char*)buf {
	self = [self init];

	[self initBuffer:buf];

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

- (size_t)length {
	return strlen(self->buffer);
}

@end