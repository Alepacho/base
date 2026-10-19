#include "test.h"

@interface SingleThreadTest : BaseObject {
}

- (void)exec;

@end

@implementation SingleThreadTest

- (id)init {
	if (self = [super init]) {
		//
	}
	return self;
}
- (void)dealloc {
	[super dealloc];
}

- (Number*)function:(Array<Number*>*)args {
	const Number* n = [args getFirst];
	[System debug:"n: %zu", [n value]];

	int i = 0;
	for (;;) {
		[System debug:"Thread function loop: %i", i++];
		if (i == [n value]) break;
	}

	return [[Number new] set:[n value]];
}

- (void)exec {
	Thread* t = [Thread new];
	Array<Number*>* args = [Array new];
	[args push:[[Number new] set:50]];

	[t create:[[Selector new] setObject:self setSelector:@selector(function:)]
		 args:args];
	// [t create:[[Selector new] setObject:self
	// setSelector:@selector(function:)]];

	// [[t selector] perform];
	int i = 10;
	while (i-- > 0) {
		[System debug:"Exec function loop: %i", i];
	}
	int code = [t join];
	Number* result = [t result];
	[System debug:"Exit code: %i, result: %zu", code, [result value]];

	[result release];
	[t release];
}

@end

// https://stackoverflow.com/questions/25319825/how-to-use-atomic-variables-in-c
@interface AtomicThreadTest : BaseObject {
	BaseAtomic(int) acnt;
	// BaseAtomic(Number*) anum;
	int cnt;
}

@property(nonatomic) int cntp;

- (void)exec;

@end

@implementation AtomicThreadTest

- (id)init {
	if (self = [super init]) {
		//
		cnt = 0;
		self.cntp = 0;
		acnt = 0;
	}
	return self;
}
- (void)dealloc {
	[super dealloc];
}

- (void)function:(Array<Number*>*)args {
	for (int n = 0; n < 1000; ++n) {
		++cnt;
		++self.cntp;
		++acnt;
	}
}

- (void)exec {
	Array<Thread*>* threads = [Array<Thread*> new];
	int c = 10;
	for (int i = 0; i < c; i++) {
		[System debug:"creating thread: %i", i];
		[threads push:[Thread new]];
	}

	for (int i = 0; i < c; i++)
		[[threads getByIndex:i]
			create:[[Selector new] setObject:self
								 setSelector:@selector(function:)]];
	for (int i = 0; i < c; i++)
		[[threads getByIndex:i] join];

	[System debug:"The atomic counter is %i", acnt];
	[System debug:"The non-atomic counter is %i", cnt];
	[System debug:"The non-atomic property is %i", self.cntp];
	[threads release];
}

@end

@implementation TestThreads

- (id)init {
	if (self = [super init]) {
		thread = nil;
	}
	return self;
}

- (void)dealloc {
	if (thread) {
		[thread release];
		thread = nil;
	}
	[super dealloc];
}

+ (void)execute {
	[System debug:"Thread test begin"];

	SingleThreadTest* test1 = [SingleThreadTest new];
	[test1 exec];
	[test1 release];

	AtomicThreadTest* test2 = [AtomicThreadTest new];
	[test2 exec];
	[test2 release];

	[System debug:"Thread test end"];
}

@end
