#pragma once

#ifndef BASE_SELECTOR_H
#define BASE_SELECTOR_H

#include "base.h"

@interface Selector : BaseObject {
	id obj;
	SEL sel;
}

- (id)init;
- (void)dealloc;

- (id)object;
- (id)setObject:(id)newObject;
- (SEL)selector;
- (id)setSelector:(SEL)newSelector;

- (id)perform;
- (id)perform:(SEL)selector;
+ (id)perform:(SEL)selector object:(id)object;

@end

#endif // BASE_SELECTOR_H
