// Thread, plus thread safety of the reference counting.

#include "unit.h"

static atomic_int workerDone = 0;

@interface Worker : BaseObject {
	BaseAtomic(int) counter;
	atomic_int gateOpen;
	atomic_int entered;
}
- (id)sum:(Array<Number*>*)args;
- (id)count:(Array*)args;
- (id)quit:(Array<Number*>*)args;
- (id)wait:(Array*)args;
- (id)hammer:(Array*)args;
- (int)counter;
- (BOOL)entered;
- (void)open;
@end

@implementation Worker
- (id)sum:(Array<Number*>*)args {
	Size total = 0;
	for (Size i = 0; i < [args count]; i++)
		total += [[args getByIndex:i] value];
	return [[Number alloc] initValue:total];
}
- (id)count:(Array*)args {
	for (int i = 0; i < 1000; i++)
		atomic_fetch_add(&counter, 1);
	atomic_fetch_add(&workerDone, 1);
	return nil;
}
- (id)quit:(Array<Number*>*)args {
	[Thread exit:(int)[[args getFirst] value]];
	return nil; // unreachable
}
- (id)wait:(Array*)args {
	atomic_store(&entered, 1);
	while (!atomic_load(&gateOpen))
		[Thread yield];
	return [[Number alloc] initValue:[args count]];
}
- (id)hammer:(Array*)args {
	id object = [args getFirst];
	for (int i = 0; i < 100000; i++) {
		[object retain];
		[object release];
	}
	return nil;
}
- (int)counter {
	return atomic_load(&counter);
}
- (BOOL)entered {
	return atomic_load(&entered) != 0;
}
- (void)open {
	atomic_store(&gateOpen, 1);
}
@end

static Array* numbers(Size count) {
	Array* a = [Array new];
	for (Size i = 1; i <= count; i++)
		[a push:probe(i)];
	return a;
}

static Selector* job(Worker* w, SEL sel) {
	return [[Selector new] setObject:w setSelector:sel];
}

static void testIdle(void) {
	Thread* t = [Thread new];
	CHECK([t args] == nil);
	CHECK([t selector] == nil);
	CHECK([t result] == nil);
	CHECK([t join] == 0);
	CHECK(![t detach]);
	[Thread yield];
	[t release];
}

static void testRunning(void) {
	Worker* w = [Worker new];
	Thread* t = [Thread new];
	Array* args = numbers(3);
	Selector* sel = job(w, @selector(wait:));

	[t create:sel args:args];
	while (![w entered])
		[Thread yield];

	// accessors while the thread runs
	CHECK([t args] == args);
	CHECK([t selector] == sel);
	CHECK([t result] == nil);
	Selector* extra = [Selector new];
	CHECK_THROWS_MESSAGE([t create:extra], "already created");
	[extra release];

	[w open];
	CHECK([t join] == 0);
	Number* result = [t result];
	CHECK([result value] == 3);
	[result release];
	CHECK([t args] == nil);
	CHECK([t selector] == nil);

	[t release];
	[w release];
}

static void testJoin(void) {
	Worker* w = [Worker new];
	Thread* t = [Thread new];

	// result, and arguments released with the thread
	atomic_store(&probeDeallocs, 0);
	[t create:job(w, @selector(sum:)) args:numbers(10)];
	CHECK([t join] == 0);
	Number* sum = [t result];
	CHECK([sum value] == 55);
	[sum release];
	CHECK(atomic_load(&probeDeallocs) == 10);
	CHECK([t join] == 0); // joining twice is harmless

	// create: without arguments passes an empty array
	[t create:job(w, @selector(sum:))];
	CHECK([t join] == 0);
	sum = [t result];
	CHECK([sum value] == 0);
	[sum release];

	// exit codes from +exit:
	Array* code = [Array new];
	[code push:[[Number alloc] initValue:7]];
	[t create:job(w, @selector(quit:)) args:code];
	CHECK([t join] == 7);
	CHECK([t result] == nil); // +exit: returns no object

	code = [Array new];
	[code push:[[Number alloc] initValue:(Size)-1]];
	[t create:job(w, @selector(quit:)) args:code];
	CHECK([t join] == -1);

	// releasing an unjoined thread joins it
	Thread* t2 = [Thread new];
	[t2 create:job(w, @selector(count:))];
	[t2 release];
	CHECK([w counter] == 1000);

	[t release];
	[w release];
}

static void testDetach(void) {
	Worker* w = [Worker new];
	Thread* t = [Thread new];

	// the thread outlives the Thread object and frees its own arguments
	atomic_store(&workerDone, 0);
	atomic_store(&probeDeallocs, 0);
	[t create:job(w, @selector(count:)) args:numbers(1)];
	CHECK([t detach]);
	CHECK(![t detach]);
	CHECK([t args] == nil);
	CHECK([t join] == 0); // nothing to join anymore
	[t release];
	for (int i = 0; i < 1000000 && atomic_load(&probeDeallocs) == 0; i++)
		[Thread yield];
	CHECK(atomic_load(&workerDone) == 1);
	CHECK(atomic_load(&probeDeallocs) == 1);

	// detaching a thread that is finishing or has already finished
	t = [Thread new];
	atomic_store(&probeDeallocs, 0);
	[t create:job(w, @selector(count:)) args:numbers(1)];
	while (atomic_load(&workerDone) < 2)
		[Thread yield];
	CHECK([t detach]);
	for (int i = 0; i < 1000000 && atomic_load(&probeDeallocs) == 0; i++)
		[Thread yield];
	CHECK(atomic_load(&probeDeallocs) == 1);
	[t release];

	[w release];
}

static void testConcurrency(void) {
	Worker* w = [Worker new];

	// many threads, released (and joined) by the array
	Array<Thread*>* threads = [Array new];
	for (int i = 0; i < 8; i++) {
		Thread* th = [Thread new];
		[th create:job(w, @selector(count:))];
		[threads push:th];
	}
	[threads release];
	CHECK([w counter] == 8000);

	// retain/release from several threads at once
	atomic_store(&probeDeallocs, 0);
	Probe* shared = probe(1);
	threads = [Array new];
	for (int i = 0; i < 4; i++) {
		Array* args = [Array new];
		[args push:[shared retain]];
		Thread* th = [Thread new];
		[th create:job(w, @selector(hammer:)) args:args];
		[threads push:th];
	}
	[threads release];
	CHECK(atomic_load(&probeDeallocs) == 0);
	CHECK([shared value] == 1);
	[shared release];
	CHECK(atomic_load(&probeDeallocs) == 1);

	[w release];
}

void testThread(void) {
	testIdle();
	testRunning();
	testJoin();
	testDetach();
	testConcurrency();
}
