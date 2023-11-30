#include "base/array.h"
#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"

#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

@implementation Array

// @private

- (void)resize:(size_t)newSize {
	self->size = newSize + 1;
	self->data = realloc(self->data, self->size * sizeof(id));
}

// @public

- (id)init {
	self = [super init];

	if (self) {
		self->size = self->used = 0;
		self->data = nil;
	}

	return self;
}

- (id)initWithSize:(size_t)newSize {
	self = [self init];
	[self resize:newSize];
	return self;
}

- (void)dealloc {
	if (self->data != nil) {
		[self clear];
	}

	[super dealloc];
}

- (size_t)count {
	return self->used;
}

- (size_t)size {
	return self->size;
}

- (void)clear {
	for (size_t i = 0; i < [self count]; i++) {
		[self pop];
	}
	free(self->data);
	self->data = nil;
}

- (id)push:(id)value {
	if (self->used >= self->size) {
		[self resize:self->size * 2];
	}
	// printf("used: %zu\n", used);
	// printf("size: %zu\n", size);
	id result = self->data[self->used] = [value retain];
	self->used++;
	return result;
}

- (void)pop {
	if (self->used == 0) return;
	[self->data[--self->used] release];
}

- (id)getByIndex:(size_t)index {
	@try {
		if (index >= self->used)
			@throw [[Exception alloc]
				initWithFormat:"Wrong array index '%zu' (while max is %zu)!",
							   index,
							   self->used];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return nil;
	}

	return self->data[index];
}

- (void)insert:(id)value {
	[self insert:value byIndex:0];
}

- (void)insert:(id)value byIndex:(size_t)index {
	@try {
		if (index >= self->used)
			@throw [[Exception alloc]
				initWithFormat:"Wrong array index '%zu' (while max is %zu)!",
							   index,
							   self->used];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return;
	}

	size_t newSize = self->used + 1;
	if (newSize >= self->size) newSize *= 2;

	id* newData = malloc((newSize) * sizeof(id));
	memcpy(newData, self->data, index * sizeof(id));
	newData[index] = value;
	memmove(newData + index + 1,
			self->data + index,
			(self->used - index) * sizeof(id));
	free(self->data);
	self->used++;
	self->size = newSize;
	self->data = newData;
}

- (void)remove {
	[self remove:0];
}

- (void)remove:(size_t)index {
	@try {
		if (index >= self->used)
			@throw [[Exception alloc]
				initWithFormat:"Wrong array index '%zu' (while max is %zu)!",
							   index,
							   self->used];
		if (self->used == 0)
			@throw [[Exception alloc]
				initWithFormat:"Unable to remove array element: %s!",
							   "Array is empty"];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return;
	}

	[self->data[index] release];

	id* newData = malloc((self->size) * sizeof(id));
	memcpy(newData, self->data, index * sizeof(id));

	memmove(newData + index,
			self->data + index + 1,
			(self->used - index - 1) * sizeof(id));
	free(self->data);
	self->used--;
	self->data = newData;
}

@end
