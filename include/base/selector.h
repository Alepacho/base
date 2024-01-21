#pragma once

#ifndef BASE_SELECTOR_H
#define BASE_SELECTOR_H

#include "array.h"
#include "base.h"

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
