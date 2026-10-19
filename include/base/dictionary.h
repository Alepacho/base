#pragma once
#ifndef BASE_DICTIONARY_H
#define BASE_DICTIONARY_H

#include "array.h"
#include "base.h"

// A hash table. Keys are compared with `isEqual:` and `hash` (a String key
// matches any String with the same bytes, a Number one any equal Number).
// The order of the entries is not defined.
//
// Ownership, as for Array: `set:forKey:` takes over the references to the key
// and the value, and the dictionary releases them when the entry is removed
// or replaced, or when it is destroyed. If the key is already there, the new
// value replaces the old one (released) and the new key is released, the
// stored one is kept. If `set:forKey:` throws, both still belong to the
// caller. `retain` an object to keep it alive.
//
// A key must not change (in the sense of `isEqual:`) while it is stored.
// Running out of memory throws an Exception, the dictionary is then unchanged.
@interface Dictionary<__covariant K, __covariant V> : BaseObject {
	void* entries;
	BaseSize used;
	BaseSize capacity;
}

- (id)init;
// Room for `count` entries before the table has to grow.
- (id)initWithSize:(BaseSize)count;
- (void)dealloc;

- (BaseSize)count;

// Throws an Exception for a nil key or value.
- (void)set:(V)value forKey:(K)key;
// nil when the key is not there. The value still belongs to the dictionary.
- (V)get:(K)key;
- (BOOL)has:(K)key;
// Releases the key and the value. Returns NO if the key was not there.
- (BOOL)remove:(K)key;
// Releases every key and value.
- (void)clear;

// New arrays holding the keys / values (retained), owned by the caller.
// Both are in the same order.
- (Array<K>*)copyKeys;
- (Array<V>*)copyValues;

// Dictionaries are equal when they hold equal keys with equal values.
- (BOOL)isEqual:(id)object;
- (BaseSize)hash;
// A new dictionary holding the same keys and values (retained, not copied).
- (id)copy;
// "{key: value, ...}", from the descriptions of the keys and values.
- (String*)copyDescription;

@end

#endif // BASE_DICTIONARY_H
