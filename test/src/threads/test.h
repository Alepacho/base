#pragma once
#include "../test.h"

@interface TestThreads : BaseObject <Test> {
	Thread* thread;
}

- (id)init;
- (void)dealloc;

@end
