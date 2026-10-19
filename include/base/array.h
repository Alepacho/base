#pragma once
#ifndef BASE_ARRAY_H
#define BASE_ARRAY_H

#include "base.h"

// Returns YES when `a` must be placed after `b` (e.g. `a > b` sorts ascending).
typedef BOOL (*_BaseSortFn)(id a, id b);

// Ownership: the array takes over the reference passed to `push:`/`insert:`
// and releases its elements when they are removed (unless asked not to)
// or when the array is destroyed. `retain` an element to keep it alive.
//
// Methods taking an index throw an Exception when it is out of range.
//
// * subtypes are acceptable
@interface Array<__covariant T> : BaseObject {
	T* data;
	Size used;
	Size size;
}

- (id)init;
- (id)initWithSize:(Size)newSize;
- (void)dealloc;

- (Size)count;
- (Size)size;

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
- (void)insert:(T)value byIndex:(Size)index;

// Removes the first element.
- (void)remove;
- (void)remove:(Size)index;
- (void)remove:(Size)index withRelease:(BOOL)flag;

- (void)swap:(Size)a to:(Size)b;
// Stable sort.
- (id)sort:(_BaseSortFn)func;

// Return nil on an empty array.
- (T)getFirst;
- (T)getLast;

// TODO: change it to 'getByClass:(Class)class'
// - (T)getByObject:(T)object;

// Returns BASE_NOT_FOUND when the object is not in the array.
- (Size)getIndexByObject:(T)object;
- (T)getByIndex:(Size)index;
@end

#endif // BASE_ARRAY_H
