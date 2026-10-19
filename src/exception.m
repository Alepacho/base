#include "base/exception.h"
#include "base/string.h"

#include <stdarg.h>

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

	if (self) {
		va_list args;
		va_start(args, fmt);
		[self->message setFormat:fmt arguments:args];
		va_end(args);
	}

	return self;
}

- (id)initWithString:(String*)str {
	self = [self init];

	if (self) {
		[self->message setString:str];
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

@end
