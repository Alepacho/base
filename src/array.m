#include "base/array.h"
#include "base/exception.h"
#include "base/string.h"
#include "internal.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

@implementation Array

// @private

- (void)resize:(BaseSize)newSize {
	if (newSize == 0) {
		free(self->data);
		self->data = nil;
		self->size = 0;
		return;
	}

	// The byte count must not wrap around (it would allocate too little).
	if (newSize > SIZE_MAX / sizeof(id))
		baseThrowOutOfMemory("an array can not hold %zu elements!", newSize);

	id* newData = realloc(self->data, (size_t)newSize * sizeof(id));
	if (newData == nil)
		baseThrowOutOfMemory("unable to allocate %zu array elements!", newSize);
	self->data = newData;
	self->size = newSize;
}

- (void)reserveOne {
	if (self->used < self->size) return;
	[self resize:(self->size < 4) ? 4 : self->size * 2];
}

- (void)checkIndex:(BaseSize)index {
	if (index >= self->used)
		@throw [[Exception alloc]
			initWithFormat:"Wrong array index '%zu' (while count is %zu)!",
						   index,
						   self->used];
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

- (id)initWithSize:(BaseSize)newSize {
	self = [self init];
	if (self) {
		@try {
			[self resize:newSize];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}
	return self;
}

- (void)dealloc {
	[self clear];

	[super dealloc];
}

- (BaseSize)count {
	return self->used;
}

- (BaseSize)size {
	return self->size;
}

- (void)clear {
	[self clear:YES];
}

- (void)clear:(BOOL)withRelease {
	if (withRelease) {
		while (self->used > 0) {
			[self pop];
		}
	}
	self->used = 0;
	[self resize:0];
}

- (id)push:(id)value {
	if (value == nil)
		@throw
			[[Exception alloc] initWithFormat:"Pushed element in array is NIL"];

	[self reserveOne];
	self->data[self->used++] = value;
	return value;
}

- (void)pop {
	if (self->used == 0) return;

	id value = self->data[--self->used];
	self->data[self->used] = nil;
	[value release];
}

- (id)getFirst {
	if (self->used == 0) return nil;
	return self->data[0];
}

- (id)getLast {
	if (self->used == 0) return nil;
	return self->data[self->used - 1];
}

// ! quite useless method
// - (id)getByObject:(id)object {
// 	for (BaseSize i = 0; i < [self count]; i++) {
// 		if (self->data[i] == object) return self->data[i];
// 	}
// 	return nil;
// }

- (BaseSize)getIndexByObject:(id)object {
	if (object == nil) return BASE_NOT_FOUND;

	for (BaseSize i = 0; i < self->used; i++) {
		if (self->data[i] == object) return i;
	}

	return BASE_NOT_FOUND;
}

- (BaseSize)getIndexByEqualObject:(id)object {
	if (object == nil) return BASE_NOT_FOUND;

	for (BaseSize i = 0; i < self->used; i++) {
		if (self->data[i] == object || [self->data[i] isEqual:object]) return i;
	}

	return BASE_NOT_FOUND;
}

- (id)getByIndex:(BaseSize)index {
	[self checkIndex:index];
	return self->data[index];
}

- (void)insert:(id)value {
	[self insert:value byIndex:0];
}

- (void)insert:(id)value byIndex:(BaseSize)index {
	if (value == nil)
		@throw [[Exception alloc]
			initWithFormat:"Inserted element in array is NIL"];
	if (index > self->used)
		@throw [[Exception alloc]
			initWithFormat:"Wrong array index '%zu' (while count is %zu)!",
						   index,
						   self->used];

	[self reserveOne];
	memmove(self->data + index + 1,
			self->data + index,
			(self->used - index) * sizeof(id));
	self->data[index] = value;
	self->used++;
}

- (void)remove {
	[self remove:0 withRelease:YES];
}

- (void)remove:(BaseSize)index {
	[self remove:index withRelease:YES];
}

- (void)remove:(BaseSize)index withRelease:(BOOL)flag {
	[self checkIndex:index];

	id value = self->data[index];
	memmove(self->data + index,
			self->data + index + 1,
			(self->used - index - 1) * sizeof(id));
	self->data[--self->used] = nil;

	if (flag) [value release];
}

- (void)swap:(BaseSize)a to:(BaseSize)b {
	[self checkIndex:a];
	[self checkIndex:b];

	id t = self->data[a];
	self->data[a] = self->data[b];
	self->data[b] = t;
}

- (id)sort:(BaseSortFn)func {
	const BaseSize n = self->used;
	if (n < 2) return self;

	// Bottom-up merge sort: stable, O(n log n), no recursion and it never
	// reads out of bounds even with a non-strict comparator.
	id* tmp = malloc((size_t)n * sizeof(id)); // n <= size, cannot overflow
	if (tmp == nil)
		baseThrowOutOfMemory("unable to sort %zu array elements!", n);

	id* src = self->data;
	id* dst = tmp;
	for (BaseSize width = 1; width < n; width *= 2) {
		for (BaseSize lo = 0; lo < n; lo += 2 * width) {
			const BaseSize mid = (lo + width < n) ? lo + width : n;
			const BaseSize hi = (lo + 2 * width < n) ? lo + 2 * width : n;
			BaseSize i = lo, j = mid, k = lo;
			while (i < mid && j < hi) {
				// take from the right only when strictly needed to stay stable
				dst[k++] = func(src[i], src[j]) ? src[j++] : src[i++];
			}
			while (i < mid)
				dst[k++] = src[i++];
			while (j < hi)
				dst[k++] = src[j++];
		}
		id* t = src;
		src = dst;
		dst = t;
	}

	if (src != self->data) memcpy(self->data, src, n * sizeof(id));
	free(tmp);
	return self;
}

- (BOOL)isEqual:(id)object {
	if (self == object) return YES;
	if (object == nil || ![object isKindOfClass:[Array class]]) return NO;

	Array* other = object;
	if ([other count] != self->used) return NO;
	for (BaseSize i = 0; i < self->used; i++) {
		if (![self->data[i] isEqual:[other getByIndex:i]]) return NO;
	}
	return YES;
}

- (BaseSize)hash {
	BaseSize h = self->used;
	for (BaseSize i = 0; i < self->used; i++) {
		h = h * 31 + [self->data[i] hash];
	}
	return h;
}

- (id)copy {
	Array* copy = [[[self class] alloc] initWithSize:self->used];
	for (BaseSize i = 0; i < self->used; i++) {
		[copy push:[self->data[i] retain]];
	}
	return copy;
}

- (String*)copyDescription {
	String* str = [[String alloc] initWithBuffer:"["];
	@try {
		for (BaseSize i = 0; i < self->used; i++) {
			if (i > 0) [str appendBuffer:", "];
			baseAppendDescription(str, self->data[i]);
		}
		[str appendChar:']'];
	} @catch (id ex) {
		[str release];
		@throw;
	}
	return str;
}

@end
