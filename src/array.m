#include "base/array.h"
#include "base/exception.h"
#include "base/system.h"

#include <stdlib.h>
#include <string.h>

@implementation Array

// @private

- (void)resize:(Size)newSize {
	if (newSize == 0) {
		free(self->data);
		self->data = nil;
		self->size = 0;
		return;
	}

	id* newData = realloc(self->data, newSize * sizeof(id));
	if (newData == nil) {
		[System fatal:"Unable to allocate memory for %llu array elements!",
					  newSize];
	}
	self->data = newData;
	self->size = newSize;
}

- (void)reserveOne {
	if (self->used < self->size) return;
	[self resize:(self->size < 4) ? 4 : self->size * 2];
}

- (void)checkIndex:(Size)index {
	if (index >= self->used)
		@throw [[Exception alloc]
			initWithFormat:"Wrong array index '%llu' (while count is %llu)!",
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

- (id)initWithSize:(Size)newSize {
	self = [self init];
	if (self) {
		[self resize:newSize];
	}
	return self;
}

- (void)dealloc {
	[self clear];

	[super dealloc];
}

- (Size)count {
	return self->used;
}

- (Size)size {
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
// 	for (Size i = 0; i < [self count]; i++) {
// 		if (self->data[i] == object) return self->data[i];
// 	}
// 	return nil;
// }

- (Size)getIndexByObject:(id)object {
	if (object == nil) return BASE_NOT_FOUND;

	for (Size i = 0; i < self->used; i++) {
		if (self->data[i] == object) return i;
	}

	return BASE_NOT_FOUND;
}

- (id)getByIndex:(Size)index {
	[self checkIndex:index];
	return self->data[index];
}

- (void)insert:(id)value {
	[self insert:value byIndex:0];
}

- (void)insert:(id)value byIndex:(Size)index {
	if (value == nil)
		@throw [[Exception alloc]
			initWithFormat:"Inserted element in array is NIL"];
	if (index > self->used)
		@throw [[Exception alloc]
			initWithFormat:"Wrong array index '%llu' (while count is %llu)!",
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

- (void)remove:(Size)index {
	[self remove:index withRelease:YES];
}

- (void)remove:(Size)index withRelease:(BOOL)flag {
	[self checkIndex:index];

	id value = self->data[index];
	memmove(self->data + index,
			self->data + index + 1,
			(self->used - index - 1) * sizeof(id));
	self->data[--self->used] = nil;

	if (flag) [value release];
}

- (void)swap:(Size)a to:(Size)b {
	[self checkIndex:a];
	[self checkIndex:b];

	id t = self->data[a];
	self->data[a] = self->data[b];
	self->data[b] = t;
}

- (id)sort:(_BaseSortFn)func {
	const Size n = self->used;
	if (n < 2) return self;

	// Bottom-up merge sort: stable, O(n log n), no recursion and it never
	// reads out of bounds even with a non-strict comparator.
	id* tmp = malloc(n * sizeof(id));
	if (tmp == nil) {
		[System fatal:"Unable to allocate memory to sort %llu elements!", n];
	}

	id* src = self->data;
	id* dst = tmp;
	for (Size width = 1; width < n; width *= 2) {
		for (Size lo = 0; lo < n; lo += 2 * width) {
			const Size mid = (lo + width < n) ? lo + width : n;
			const Size hi = (lo + 2 * width < n) ? lo + 2 * width : n;
			Size i = lo, j = mid, k = lo;
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

@end
