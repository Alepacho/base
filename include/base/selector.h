#pragma once

#ifndef BASE_SELECTOR_H
#define BASE_SELECTOR_H

#include "base.h"

@class Array;

@interface Selector : BaseObject {
	id obj;
	SEL sel;
	id res;
}

- (id)init;
- (void)dealloc;

- (id)object;
- (id)setObject:(id)object;

- (SEL)selector;
- (id)setSelector:(SEL)selector;

- (id)setObject:(id)object setSelector:(SEL)selector;

- (IMP)method;
+ (IMP)method:(SEL)selector object:(id)object;

- (id)result;

- (id)perform;
- (id)perform:(SEL)selector;
+ (id)perform:(SEL)selector object:(id)object;
+ (id)perform:(SEL)selector object:(id)object args:(Array*)args;

- (id)performWithArgs:(Array*)args;

@end

#endif // BASE_SELECTOR_H
