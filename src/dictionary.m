#include "base/dictionary.h"
#include "base/exception.h"
#include "base/string.h"
#include "internal.h"

#include <stdint.h>
#include <stdlib.h>

// Open addressing with linear probing. Removal shifts the following entries
// back, so there are no tombstones: an empty slot ends every probe sequence.
typedef struct {
	id key; // nil for an empty slot
	id value;
	BaseSize hash;
} BaseEntry;

// The default hash is an address, whose low bits are always zero.
static BaseSize baseMix(BaseSize h) {
	h ^= h >> 33;
	h *= 0xff51afd7ed558ccdULL;
	h ^= h >> 33;
	return h;
}

@implementation Dictionary

// @private

- (BaseEntry*)table {
	return (BaseEntry*)self->entries;
}

// Index of the slot holding `key`, or of the empty slot where it would go.
- (BaseSize)find:(id)key hash:(BaseSize)hash {
	BaseEntry* table = [self table];
	const BaseSize mask = self->capacity - 1;
	for (BaseSize i = baseMix(hash) & mask;; i = (i + 1) & mask) {
		BaseEntry* e = &table[i];
		if (e->key == nil) return i;
		if (e->hash == hash && (e->key == key || [e->key isEqual:key]))
			return i;
	}
}

// Rebuilds the table with `newCapacity` slots, a power of two that is big
// enough for every entry.
- (void)rehash:(BaseSize)newCapacity {
	BaseEntry* newTable = calloc(newCapacity, sizeof(BaseEntry));
	if (newTable == NULL)
		baseThrowOutOfMemory("unable to allocate %zu dictionary slots!",
							 newCapacity);

	BaseEntry* old = [self table];
	const BaseSize oldCapacity = self->capacity;
	self->entries = newTable;
	self->capacity = newCapacity;

	const BaseSize mask = newCapacity - 1;
	for (BaseSize i = 0; i < oldCapacity; i++) {
		if (old[i].key == nil) continue;
		BaseSize j = baseMix(old[i].hash) & mask;
		while (newTable[j].key != nil)
			j = (j + 1) & mask;
		newTable[j] = old[i];
	}
	free(old);
}

// Number of slots needed for `count` entries at a load of at most 3/4.
static BaseSize baseCapacityFor(BaseSize count) {
	if (count > (SIZE_MAX / 4) / sizeof(BaseEntry))
		baseThrowOutOfMemory("a dictionary can not hold %zu entries!", count);

	const BaseSize needed = count + count / 3 + 1;
	BaseSize capacity = 8;
	while (capacity < needed)
		capacity *= 2;
	return capacity;
}

// @public

- (id)init {
	return [self initWithSize:0];
}

- (id)initWithSize:(BaseSize)count {
	self = [super init];
	if (self) {
		self->entries = NULL;
		self->used = 0;
		self->capacity = 0;
		@try {
			[self rehash:baseCapacityFor(count)];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}
	return self;
}

- (void)dealloc {
	[self clear];
	free(self->entries);
	self->entries = NULL;

	[super dealloc];
}

- (BaseSize)count {
	return self->used;
}

- (void)set:(id)value forKey:(id)key {
	if (key == nil)
		@throw [[Exception alloc] initWithFormat:"Dictionary key is NIL"];
	if (value == nil)
		@throw [[Exception alloc] initWithFormat:"Dictionary value is NIL"];

	const BaseSize hash = [key hash];
	BaseSize i = [self find:key hash:hash];
	BaseEntry* e = &[self table][i];

	if (e->key != nil) {
		// Also right when it is the same object: the caller gave us one
		// more reference to it.
		id oldValue = e->value;
		e->value = value;
		[oldValue release];
		[key release];
		return;
	}

	// Grow first, so that nothing is taken over when it throws.
	if (self->used + 1 > self->capacity - self->capacity / 4) {
		[self rehash:self->capacity * 2];
		i = [self find:key hash:hash];
		e = &[self table][i];
	}

	e->key = key;
	e->value = value;
	e->hash = hash;
	self->used++;
}

- (id)get:(id)key {
	if (key == nil) return nil;
	BaseEntry* e = &[self table][[self find:key hash:[key hash]]];
	return e->value; // nil for an empty slot
}

- (BOOL)has:(id)key {
	return [self get:key] != nil;
}

- (BOOL)remove:(id)key {
	if (key == nil) return NO;

	BaseEntry* table = [self table];
	BaseSize i = [self find:key hash:[key hash]];
	if (table[i].key == nil) return NO;

	id oldKey = table[i].key;
	id oldValue = table[i].value;

	// Moves back every following entry that may not stay after the hole.
	const BaseSize mask = self->capacity - 1;
	for (BaseSize j = (i + 1) & mask; table[j].key != nil; j = (j + 1) & mask) {
		const BaseSize ideal = baseMix(table[j].hash) & mask;
		// `j` is fine where it is when its ideal slot is cyclically in (i, j]
		const BOOL stays =
			(i <= j) ? (i < ideal && ideal <= j) : (i < ideal || ideal <= j);
		if (stays) continue;
		table[i] = table[j];
		i = j;
	}
	table[i].key = nil;
	table[i].value = nil;
	self->used--;

	// Released last: their dealloc may use the dictionary.
	[oldKey release];
	[oldValue release];
	return YES;
}

- (void)clear {
	BaseEntry* table = [self table];
	for (BaseSize i = 0; i < self->capacity && self->used > 0; i++) {
		if (table[i].key == nil) continue;
		id key = table[i].key;
		id value = table[i].value;
		table[i].key = nil;
		table[i].value = nil;
		self->used--;
		[key release];
		[value release];
	}
}

- (Array*)copyKeysOrValues:(BOOL)keys {
	Array* array = [[Array alloc] initWithSize:self->used];
	BaseEntry* table = [self table];
	for (BaseSize i = 0; i < self->capacity; i++) {
		if (table[i].key == nil) continue;
		// cannot throw: the array has room for every entry
		[array push:[(keys ? table[i].key : table[i].value) retain]];
	}
	return array;
}

- (Array*)copyKeys {
	return [self copyKeysOrValues:YES];
}

- (Array*)copyValues {
	return [self copyKeysOrValues:NO];
}

- (BOOL)isEqual:(id)object {
	if (self == object) return YES;
	if (object == nil || ![object isKindOfClass:[Dictionary class]]) return NO;

	Dictionary* other = object;
	if ([other count] != self->used) return NO;

	BaseEntry* table = [self table];
	for (BaseSize i = 0; i < self->capacity; i++) {
		if (table[i].key == nil) continue;
		id value = [other get:table[i].key];
		if (value == nil || ![table[i].value isEqual:value]) return NO;
	}
	return YES;
}

- (BaseSize)hash {
	// order independent, as the entries have no order
	BaseSize h = self->used;
	BaseEntry* table = [self table];
	for (BaseSize i = 0; i < self->capacity; i++) {
		if (table[i].key == nil) continue;
		h += baseMix(table[i].hash) ^ [table[i].value hash];
	}
	return h;
}

- (id)copy {
	Dictionary* copy = [[[self class] alloc] initWithSize:self->used];
	BaseEntry* table = [self table];
	for (BaseSize i = 0; i < self->capacity; i++) {
		if (table[i].key == nil) continue;
		// cannot grow: the copy has room for every entry
		[copy set:[table[i].value retain] forKey:[table[i].key retain]];
	}
	return copy;
}

- (String*)copyDescription {
	String* str = [[String alloc] initWithBuffer:"{"];
	@try {
		BaseEntry* table = [self table];
		BOOL first = YES;
		for (BaseSize i = 0; i < self->capacity; i++) {
			if (table[i].key == nil) continue;
			if (!first) [str appendBuffer:", "];
			first = NO;
			baseAppendDescription(str, table[i].key);
			[str appendBuffer:": "];
			baseAppendDescription(str, table[i].value);
		}
		[str appendChar:'}'];
	} @catch (id ex) {
		[str release];
		@throw;
	}
	return str;
}

@end
