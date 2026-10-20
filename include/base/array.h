#pragma once
#ifndef BASE_ARRAY_H
#define BASE_ARRAY_H

#include "base.h"

// Returns YES when `a` must be placed after `b` (e.g. `a > b` sorts ascending).
typedef BOOL (*BaseSortFn)(id a, id b);

// Ownership: the array takes over the reference passed to `push:`/`insert:`
// and releases its elements when they are removed (unless asked not to)
// or when the array is destroyed. `retain` an element to keep it alive.
//
// Methods taking an index throw an Exception when it is out of range.
// Running out of memory throws an Exception, the array is then unchanged.
//
// * subtypes are acceptable
@interface Array<__covariant T> : BaseObject {
	T* data;
	BaseSize used;
	BaseSize size;
}

- (id)init;
- (id)initWithSize:(BaseSize)newSize;
- (void)dealloc;
// length?
- (BaseSize)count;
// capacity?
- (BaseSize)size;

// Releases all elements.
- (void)clear;
// Removes all elements, releasing them only when `withRelease` is YES.
- (void)clear:(BOOL)withRelease;

- (id)push:(T)value;
// Releases the last element; does nothing on an empty array.
- (void)pop;

// Inserts at the beginning.
- (void)insert:(T)value;
// `index` may be equal to `count` to append.
- (void)insert:(T)value byIndex:(BaseSize)index;

// Removes the first element.
- (void)remove;
- (void)remove:(BaseSize)index;
- (void)remove:(BaseSize)index withRelease:(BOOL)flag;

- (void)swap:(BaseSize)a to:(BaseSize)b;
// Stable sort.
- (id)sort:(BaseSortFn)func;

// Return nil on an empty array.
- (T)getFirst;
- (T)getLast;

// TODO: change it to 'getByClass:(Class)class'
// - (T)getByObject:(T)object;

// Returns BASE_NOT_FOUND when the object is not in the array.
// `getIndexByObject:` looks for that very object, `getIndexByEqualObject:`
// for one that `isEqual:` to it.
- (BaseSize)getIndexByObject:(T)object;
- (BaseSize)getIndexByEqualObject:(T)object;
- (T)getByIndex:(BaseSize)index;

// Arrays are equal when their elements are equal, in the same order.
- (BOOL)isEqual:(id)object;
- (BaseSize)hash;
// A new array holding the same elements (they are retained, not copied).
- (id)copy;
// "[first, second]", from the descriptions of the elements.
- (String*)copyDescription;
@end

#endif // BASE_ARRAY_H
