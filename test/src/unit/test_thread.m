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
- (id)fail:(Array*)args;
- (int)counter;
- (BOOL)entered;
- (void)open;
@end

@implementation Worker
- (id)sum:(Array<Number*>*)args {
	BaseSize total = 0;
	for (BaseSize i = 0; i < [args count]; i++)
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
- (id)fail:(Array*)args {
	@throw [[Exception alloc] initWithFormat:"failed with %zu", [args count]];
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

static Array* numbers(BaseSize count) {
	Array* a = [Array new];
	for (BaseSize i = 1; i <= count; i++)
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
	[code push:[[Number alloc] initValue:(BaseSize)-1]];
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

static void testExceptions(void) {
	Worker* w = [Worker new];
	Thread* t = [Thread new];

	// join rethrows what the selector threw, after cleaning up
	atomic_store(&probeDeallocs, 0);
	[t create:job(w, @selector(fail:)) args:numbers(2)];
	CHECK_THROWS_MESSAGE([t join], "failed with 2");
	CHECK(atomic_load(&probeDeallocs) == 2);
	CHECK([t args] == nil);
	CHECK([t result] == nil);
	CHECK([t join] == 0); // nothing left to join

	// the Thread can be reused
	[t create:job(w, @selector(sum:)) args:numbers(3)];
	CHECK([t join] == 0);
	Number* sum = [t result];
	CHECK([sum value] == 6);
	[sum release];

	// nobody joins: the exception is reported, the process keeps running
	atomic_store(&probeDeallocs, 0);
	[t create:job(w, @selector(fail:)) args:numbers(1)];
	CHECK([t detach]);
	for (int i = 0; i < 1000000 && atomic_load(&probeDeallocs) == 0; i++)
		[Thread yield];
	CHECK(atomic_load(&probeDeallocs) == 1);
	[t release];

	// releasing an unjoined thread does not throw out of dealloc
	atomic_store(&probeDeallocs, 0);
	t = [Thread new];
	[t create:job(w, @selector(fail:)) args:numbers(1)];
	[t release];
	CHECK(atomic_load(&probeDeallocs) == 1);

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

	// a detached thread that calls +exit: still releases its arguments
	t = [Thread new];
	atomic_store(&probeDeallocs, 0);
	Array* code = numbers(1);
	[t create:job(w, @selector(quit:)) args:code];
	CHECK([t detach]);
	for (int i = 0; i < 1000000 && atomic_load(&probeDeallocs) == 0; i++)
		[Thread yield];
	CHECK(atomic_load(&probeDeallocs) == 1);
	[t release];

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

// Protects a plain (non-atomic) counter with a Mutex.
@interface Locker : BaseObject {
	Mutex* mutex;
	int counter;
}
- (id)initWithMutex:(Mutex*)m;
- (id)add:(Array*)args;
- (id)tryLock:(Array*)args;
- (int)counter;
@end

@implementation Locker
- (id)initWithMutex:(Mutex*)m {
	self = [super init];
	if (self) {
		mutex = m;
		counter = 0;
	}
	return self;
}
- (id)add:(Array*)args {
	for (int i = 0; i < 10000; i++) {
		[mutex lock];
		counter++;
		[mutex unlock];
	}
	return nil;
}
- (id)tryLock:(Array*)args {
	if (![mutex tryLock]) return nil;
	[mutex unlock];
	return [[Number alloc] initValue:1];
}
- (int)counter {
	return counter;
}
@end

// Result of [Locker tryLock:] called from another thread.
static BOOL tryLockElsewhere(Locker* l) {
	Thread* t = [Thread new];
	[t create:[[Selector new] setObject:l setSelector:@selector(tryLock:)]];
	[t join];
	Number* r = [t result];
	[t release];
	if (r == nil) return NO;
	[r release];
	return YES;
}

static void testMutex(void) {
	// plain
	Mutex* m = [Mutex new];
	Locker* l = [[Locker alloc] initWithMutex:m];
	CHECK(![m isRecursive]);
	CHECK([m tryLock]);
	CHECK(![m tryLock]); // not even by the owner
	CHECK(!tryLockElsewhere(l));
	[m unlock];
	CHECK(tryLockElsewhere(l));
	[m lock];
	CHECK(!tryLockElsewhere(l));
	[m unlock];

	// contention
	Array<Thread*>* threads = [Array new];
	for (int i = 0; i < 8; i++) {
		Thread* th = [Thread new];
		[th create:[[Selector new] setObject:l setSelector:@selector(add:)]];
		[threads push:th];
	}
	[threads release];
	CHECK([l counter] == 80000);
	[l release];
	[m release];

	// recursive
	m = [[Mutex alloc] initRecursive:YES];
	l = [[Locker alloc] initWithMutex:m];
	CHECK([m isRecursive]);
	[m lock];
	CHECK([m tryLock]);
	[m lock];
	CHECK(!tryLockElsewhere(l));
	[m unlock];
	[m unlock];
	CHECK(!tryLockElsewhere(l)); // still held once
	[m unlock];
	CHECK(tryLockElsewhere(l));
	[l release];
	[m release];
}

// A queue of one Number, filled by a producer and emptied by consumers.
@interface Box : BaseObject {
  @public
	Mutex* mutex;
	Condition* changed;
	BaseSize value; // 0 when empty
	BaseSize taken;
	BOOL closed;
}
- (id)consume:(Array*)args;
@end

@implementation Box
- (id)init {
	self = [super init];
	if (self) {
		mutex = [Mutex new];
		changed = [Condition new];
	}
	return self;
}
- (void)dealloc {
	[changed release];
	[mutex release];
	[super dealloc];
}
- (id)consume:(Array*)args {
	BaseSize sum = 0;
	[mutex lock];
	for (;;) {
		while (value == 0 && !closed)
			[changed wait:mutex];
		if (value == 0) break; // closed and empty
		sum += value;
		value = 0;
		taken++;
		[changed broadcast];
	}
	[mutex unlock];
	return [[Number alloc] initValue:sum];
}
@end

static void testCondition(void) {
	Box* box = [Box new];

	// producer / consumers: every value is consumed exactly once
	Thread* consumers[4];
	for (int i = 0; i < 4; i++) {
		consumers[i] = [Thread new];
		[consumers[i] create:[[Selector new] setObject:box
										   setSelector:@selector(consume:)]];
	}
	for (BaseSize v = 1; v <= 1000; v++) {
		[box->mutex lock];
		while (box->value != 0)
			[box->changed wait:box->mutex];
		box->value = v;
		[box->changed broadcast];
		[box->mutex unlock];
	}
	[box->mutex lock];
	while (box->value != 0)
		[box->changed wait:box->mutex];
	box->closed = YES;
	[box->changed broadcast];
	[box->mutex unlock];

	BaseSize total = 0;
	for (int i = 0; i < 4; i++) {
		CHECK([consumers[i] join] == 0);
		Number* sum = [consumers[i] result];
		total += [sum value];
		[sum release];
		[consumers[i] release];
	}
	CHECK(total == 1000 * 1001 / 2);
	CHECK(box->taken == 1000);

	// timeouts
	[box->mutex lock];
	CHECK(![box->changed wait:box->mutex timeout:0.05]);
	CHECK(![box->changed wait:box->mutex timeout:0]);
	CHECK(![box->changed wait:box->mutex timeout:-1]);
	CHECK(![box->changed wait:box->mutex timeout:0.0 / 0.0]);
	[box->mutex unlock];
	// signals without waiters are harmless
	[box->changed signal];
	[box->changed broadcast];

	// a signal before the timeout
	box->closed = NO;
	Thread* t = [Thread new];
	[t create:[[Selector new] setObject:box setSelector:@selector(consume:)]];
	[box->mutex lock];
	box->value = 5;
	[box->changed broadcast];
	BOOL signaled = YES;
	while (box->value != 0 && signaled)
		signaled = [box->changed wait:box->mutex timeout:10];
	CHECK(signaled);
	box->closed = YES;
	[box->changed broadcast];
	[box->mutex unlock];
	[t join];
	Number* sum = [t result];
	CHECK([sum value] == 5);
	[sum release];
	[t release];

	// a recursive mutex works too
	Mutex* recursive = [[Mutex alloc] initRecursive:YES];
	[recursive lock];
	CHECK(![box->changed wait:recursive timeout:0.01]);
	[recursive unlock];
	[recursive release];

	CHECK_THROWS([box->changed wait:nil]);
	CHECK_THROWS([box->changed wait:nil timeout:1]);

	[box release];
}

void testThread(void) {
	testIdle();
	testRunning();
	testJoin();
	testDetach();
	testExceptions();
	testConcurrency();
	testMutex();
	testCondition();
}
