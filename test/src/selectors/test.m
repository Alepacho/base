#include "test.h"

@implementation TestSelectors

- (void)callback2 {
	[System debug:"Callback 2!"];
}

+ (void)callback1 {
	[System debug:"Callback 1!"];
}

+ (void)execute {
	[System debug:"Selector test begin"];
	[Selector perform:@selector(callback1) object:self];
	[Selector perform:@selector(callback2) object:self];
	[System debug:"Selector test end"];
}

@end
