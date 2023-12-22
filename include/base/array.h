#pragma once
#ifndef BASE_ARRAY_H
#define BASE_ARRAY_H

#include "base.h"

typedef BOOL (*_BaseSortFn)(id a, id b);

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

- (void)clear;
- (void)clear:(BOOL)withDealloc;

- (id)push:(T)value;
- (void)pop;

- (void)insert:(T)value;
- (void)insert:(T)value byIndex:(Size)index;

- (void)remove;
- (void)remove:(Size)index;
- (void)remove:(Size)index withDealloc:(BOOL)flag;

- (void)swap:(Size)a to:(Size)b;
- (id)sort:(_BaseSortFn)func;

- (T)getFirst;
- (T)getLast;

// TODO: change it to 'getByClass:(Class)class'
// - (T)getByObject:(T)object;

//
- (T)getByIndex:(Size)index;
@end

#endif // BASE_ARRAY_H
