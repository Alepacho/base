#pragma once
#ifndef BASE_ARRAY_H
#define BASE_ARRAY_H

#include "base.h"

typedef BOOL (*_BaseSortFn)(id a, id b);

// * subtypes are acceptable
@interface Array<__covariant T> : BaseObject {
	T* data;
	size_t used;
	size_t size;
}

- (id)init;
- (id)initWithSize:(size_t)newSize;
- (void)dealloc;

- (size_t)count;
- (size_t)size;

- (void)clear;

- (id)push:(T)value;
- (void)pop;

- (void)insert:(T)value;
- (void)insert:(T)value byIndex:(size_t)index;

- (void)remove;
- (void)remove:(size_t)index;

- (void)swap:(size_t)a to:(size_t)b;
- (id)sort:(_BaseSortFn)func;

- (T)getFirst;
- (T)getLast;
- (T)getByObject:(T)object;
- (T)getByIndex:(size_t)index;
@end

#endif // BASE_ARRAY_H
