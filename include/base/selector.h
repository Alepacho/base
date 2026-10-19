#pragma once

#ifndef BASE_SELECTOR_H
#define BASE_SELECTOR_H

#include "array.h"
#include "base.h"

// Calls a method by its selector. Works with instance and class objects.
//
// The method must return an object (or a Class), or nothing, and take either
// no argument or one object argument; the argument is ignored by methods that
// take none, and void methods give `nil`. An Exception is thrown when the
// object does not respond to the selector or the method has another type.
//
// Selector does not own the object, the argument or the result.
@interface Selector<__covariant T> : BaseObject {
	id obj;
	SEL sel;
	id res;
	T arg;
}

- (id)init;
- (void)dealloc;

- (id)object;
- (id)setObject:(id)object;

- (SEL)selector;
- (id)setSelector:(SEL)selector;

- (T)argument;
- (id)setArgument:(T)argument;

- (id)setObject:(id)object setSelector:(SEL)selector;
- (id)setObject:(id)object setSelector:(SEL)selector setArgument:(T)argument;

- (IMP)method;
+ (IMP)method:(SEL)selector object:(id)object;

- (id)result;

- (id)perform;
- (id)perform:(SEL)selector;
- (id)performWithArgs:(Array*)arguments;

+ (id)perform:(SEL)selector object:(id)object;
+ (id)perform:(SEL)selector object:(id)object argument:(T)argument;

@end

#endif // BASE_SELECTOR_H
