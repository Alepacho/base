#include "test.h"

static TestSelectors* test;

@interface Foo : BaseObject

- (void)func;

@end

@implementation Foo

- (id)init {
	if (self = [super init]) {
		[test setSelFo:[[Selector new] setObject:self
									 setSelector:@selector(func)]];
	}
	return self;
}

- (void)func {
	[System debug:"foo"];
}

@end

@implementation TestSelectors

- (id)init {
	if (self = [super init]) {
		selFoo = nil;
	}
	return self;
}
- (void)dealloc {
	[super dealloc];
}

- (Selector*)selFoo {
	return selFoo;
}

- (id)setSelFo:(Selector*)newSelFoo {
	selFoo = newSelFoo;
	return self;
}

- (void)callback2 {
	[System debug:"Callback 2!"];
}

+ (void)callback1 {
	[System debug:"Callback 1!"];
}

+ (void)execute {
	test = [TestSelectors new];
	Foo* foo = [Foo new];

	[System debug:"Selector test begin"];
	[Selector perform:@selector(callback1) object:self];

	// @try {
	// 	[Selector perform:@selector(callback2) object:self];
	// } @catch (Exception* ex) {
	// 	[System debug:"Got exception: %s", [ex message]];
	// }

	[[test selFoo] perform];
	[foo func];

	[System debug:"Selector test end"];
}

@end
