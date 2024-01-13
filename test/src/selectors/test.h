#pragma once
#include "../test.h"

@interface TestSelectors : BaseObject <Test> {
	Selector* selFoo;
}

- (id)init;
- (void)dealloc;

- (Selector*)selFoo;
- (id)setSelFo:(Selector*)newSelFoo;

@end