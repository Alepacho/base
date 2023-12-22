#include "base/array.h"
#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"

#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

@implementation Array

// @private

- (void)resize:(Size)newSize {
	self->size = newSize + 1;
	self->data = realloc(self->data, self->size * sizeof(id));
}

- (void)sortPartition:(_BaseSortFn)func first:(int)f last:(int)l {
	int i, j, p;

	if (f < l) {
		p = f;
		i = f;
		j = l;
		while (i < j) {
			while (!func(data[i], data[p]) && i < l)
				i++;

			while (func(data[j], data[p]))
				j--;

			if (i < j) {
				[self swap:i to:j];
			}
		}

		[self swap:p to:j];

		[self sortPartition:func first:f last:j - 1];
		[self sortPartition:func first:j + 1 last:l];
	}
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

- (id)initWithSize:(Size)newSize {
	self = [self init];
	[self resize:newSize];
	return self;
}

- (void)dealloc {
	if (self->used != 0 && self->data != nil) {
		[self clear];
	}

	[super dealloc];
}

- (Size)count {
	return self->used;
}

- (Size)size {
	return self->size;
}

- (void)clear {
	for (Size i = 0; i < [self count]; i++) {
		[self pop];
	}

	self->size = self->used = 0;
	if (self->data != nil) {
		free(self->data);
		self->data = nil;
	}
}

- (void)clear:(BOOL)withDealloc {
	if (withDealloc) {
		for (size_t i = 0; i < [self count]; i++) {
			[self pop];
		}
	}
	self->size = self->used = 0;
	if (self->data != nil) {
		free(self->data);
		self->data = nil;
	}
}

- (id)push:(id)value {
	if (value == nil)
		@throw
			[[Exception alloc] initWithFormat:"Pushed element in array is NIL"];

	if (self->used >= self->size) {
		[self resize:self->size * 2];
	}
	// printf("used: %zu\n", used);
	// printf("size: %zu\n", size);
	id result = self->data[self->used] = value; //[value retain];
	self->used++;
	return result;
}

- (void)pop {
	if (self->used == 0) return;

	Size _at = --self->used;
	id _data = self->data[_at];

	if (_data == nil)
		@throw [[Exception alloc]
			initWithFormat:"Popped element in array is NIL (at %i)", _at];

	if (_data == NULL) {
		@throw [[Exception alloc]
			initWithFormat:"Popped element in array is NULL (at %i)", _at];
	}

	[_data dealloc];
	_data = nil;
}

- (id)getFirst {
	@try {
		if ([self count] == 0)
			@throw [[Exception alloc]
				initWithFormat:"Unable to get first array element: %s!",
							   "Array is empty"];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return nil;
	}

	return self->data[0];
}

- (id)getLast {
	@try {
		if ([self count] == 0)
			@throw [[Exception alloc]
				initWithFormat:"Unable to get first array element: %s!",
							   "Array is empty"];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return nil;
	}

	return self->data[[self count] - 1];
}

// ! quite useless method
// - (id)getByObject:(id)object {
// 	@try {
// 		if (object == nil)
// 			@throw [[Exception alloc]
// 				initWithFormat:"Unable to get array element: %s!",
// 							   "Object is nil"];
// 	} @catch (Exception* ex) {
// 		[System error:"%s\n", [ex message]];
// 		[ex release];
// 		return nil;
// 	}

// 	for (Size i = 0; i < [self count]; i++) {
// 		if (self->data[i] == object) return self->data[i];
// 	}
// 	return nil;
// }

- (Size)getIndexByObject:(id)object {
	@try {
		if (object == nil)
			@throw [[Exception alloc]
				initWithFormat:"Unable to get method argument: %s!",
							   "Object is nil"];
	} @catch (Exception* ex) {
		[System error:"%s\n", [ex message]];
		[ex release];
		return -1;
	}
	for (Size i = 0; i < [self count]; i++) {
		if (self->data[i] == object) return i;
	}

	return -1;
}

- (id)getByIndex:(Size)index {
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

- (void)insert:(id)value byIndex:(Size)index {
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

	Size newSize = self->used + 1;
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
	[self remove:0 withDealloc:YES];
}

- (void)remove:(Size)index {
	[self remove:index withDealloc:YES];
}

- (void)remove:(Size)index withDealloc:(BOOL)flag {
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

	if (flag) {
		[self->data[index] dealloc];
		self->data[index] = nil;
	}

	id* newData = malloc((self->size) * sizeof(id));
	memcpy(newData, self->data, index * sizeof(id));

	memmove(newData + index,
			self->data + index + 1,
			(self->used - index - 1) * sizeof(id));
	free(self->data);
	self->used--;
	self->data = newData;
}

- (void)swap:(Size)a to:(Size)b {
	// TODO: add bounds check
	id t = self->data[a];
	self->data[a] = self->data[b];
	self->data[b] = t;
}

- (id)sort:(_BaseSortFn)func {
	[self sortPartition:func first:0 last:[self count] - 1];
	return self;
}

@end
