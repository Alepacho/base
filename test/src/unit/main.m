// Unit tests for base. Run with `ctest` (or the `base_tests` binary).
// Build with -DBASE_SANITIZE=ON to run them under ASan/UBSan.

#include "base/all.h"

#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int checks = 0;
static int failures = 0;

#define CHECK(cond)                                                            \
	do {                                                                       \
		checks++;                                                              \
		if (!(cond)) {                                                         \
			failures++;                                                        \
			fprintf(stderr,                                                    \
					"%s:%d: CHECK failed: %s\n",                               \
					__FILE__,                                                  \
					__LINE__,                                                  \
					#cond);                                                    \
		}                                                                      \
	} while (0)

#define CHECK_THROWS(expr)                                                     \
	do {                                                                       \
		BOOL thrown = NO;                                                      \
		@try {                                                                 \
			expr;                                                              \
		} @catch (Exception * ex) {                                            \
			thrown = YES;                                                      \
			[ex release];                                                      \
		}                                                                      \
		checks++;                                                              \
		if (!thrown) {                                                         \
			failures++;                                                        \
			fprintf(stderr,                                                    \
					"%s:%d: expected exception: %s\n",                         \
					__FILE__,                                                  \
					__LINE__,                                                  \
					#expr);                                                    \
		}                                                                      \
	} while (0)

// Counts destroyed instances.
static atomic_int probeDeallocs = 0;

@interface Probe : Number
@end
@implementation Probe
- (void)dealloc {
	atomic_fetch_add(&probeDeallocs, 1);
	[super dealloc];
}
@end

static Probe* probe(Size value) {
	return [[Probe alloc] initValue:value];
}

static BOOL greater(id a, id b) {
	return [(Number*)a value] > [(Number*)b value];
}

static BOOL greaterOrEqual(id a, id b) {
	return [(Number*)a value] >= [(Number*)b value];
}

// Sort key is value / 10, the last digit records the original order.
static BOOL greaterByTens(id a, id b) {
	return [(Number*)a value] / 10 > [(Number*)b value] / 10;
}

// MARK: - BaseObject

static void testBaseObject(void) {
	CHECK([Number isMemberOfClass:[Number class]]);
	CHECK(![Probe isMemberOfClass:[Number class]]);

	Probe* p = probe(1);
	CHECK([p isMemberOfClass:[Probe class]]);
	CHECK(![p isMemberOfClass:[Number class]]);

	atomic_store(&probeDeallocs, 0);
	[p retain];
	[p release];
	CHECK(atomic_load(&probeDeallocs) == 0);
	[p release];
	CHECK(atomic_load(&probeDeallocs) == 1);

	atomic_store(&probeDeallocs, 0);
	@autoreleasepool {
		[probe(2) autorelease];
		CHECK(atomic_load(&probeDeallocs) == 0);
	}
	CHECK(atomic_load(&probeDeallocs) == 1);
}

// MARK: - String

static void testString(void) {
	String* s = [[String alloc] initWithBuffer:"abc"];
	CHECK([s compareBuffer:"abc"]);
	CHECK(![s compareBuffer:"abcdef"]);
	CHECK(![s compareBuffer:"ab"]);
	CHECK(![s compareBuffer:nil]);

	String* empty = [String new];
	CHECK([empty compareBuffer:""]);
	CHECK(![empty compareBuffer:"anything"]);

	// empty appends are no-ops, not fatal errors
	[s appendBuffer:""];
	[s appendBuffer:nil];
	[s appendFormat:"%s", ""];
	CHECK([s compareBuffer:"abc"]);

	[s appendChar:'d'];
	[s appendFormat:"-%d-%s", 42, "x"];
	CHECK([s compareBuffer:"abcd-42-x"]);
	CHECK([s length] == 9);

	// aliasing our own buffer
	[s appendBuffer:[s buffer]];
	CHECK([s compareBuffer:"abcd-42-xabcd-42-x"]);
	[s setBuffer:[s buffer] + 9];
	CHECK([s compareBuffer:"abcd-42-x"]);
	[s setString:s];
	CHECK([s compareBuffer:"abcd-42-x"]);

	[s setFormat:"%llu", (Size)18446744073709551615ULL];
	CHECK([s compareBuffer:"18446744073709551615"]);

	String* copy = [[String alloc] initWithString:s];
	CHECK([copy compareBuffer:[s buffer]]);
	CHECK([copy buffer] != [s buffer]);

	String* formatted = [[String alloc] initWithFormat:"%s=%i", "n", 7];
	CHECK([formatted compareBuffer:"n=7"]);

	[s clear];
	CHECK([s length] == 0);

	[formatted release];
	[copy release];
	[empty release];
	[s release];
}

// MARK: - Exception

static void testException(void) {
	Exception* e = [[Exception alloc] initWithFormat:"%s", ""];
	CHECK(strcmp([e message], "Unknown error") == 0);
	[e release];

	e = [[Exception alloc] initWithFormat:"code %i", 5];
	CHECK(strcmp([e message], "code 5") == 0);
	[e release];

	String* msg = [[String alloc] initWithBuffer:"from string"];
	e = [[Exception alloc] initWithString:msg];
	CHECK(strcmp([e message], "from string") == 0);
	[e release];
	[msg release];
}

// MARK: - Array

static void testArray(void) {
	atomic_store(&probeDeallocs, 0);

	Array<Probe*>* a = [Array new];
	CHECK([a count] == 0);
	CHECK([a getFirst] == nil);
	CHECK([a getLast] == nil);
	[a pop]; // no-op on empty

	// insert into an empty array and at the end
	[a insert:probe(2)];
	[a insert:probe(4) byIndex:1];
	[a insert:probe(1)];
	[a insert:probe(3) byIndex:2];
	CHECK([a count] == 4);
	for (Size i = 0; i < [a count]; i++)
		CHECK([[a getByIndex:i] value] == i + 1);

	// ownership is only transferred on success
	Probe* rejected = probe(9);
	CHECK_THROWS([a insert:rejected byIndex:10]);
	CHECK(atomic_load(&probeDeallocs) == 0);
	[rejected release];
	atomic_store(&probeDeallocs, 0);

	CHECK_THROWS([a getByIndex:4]);
	CHECK_THROWS([a remove:4]);
	CHECK_THROWS([a swap:0 to:4]);
	CHECK_THROWS([a push:nil]);

	Probe* missing = probe(0);
	CHECK([a getIndexByObject:missing] == BASE_NOT_FOUND);
	CHECK([a getIndexByObject:nil] == BASE_NOT_FOUND);
	CHECK([a getIndexByObject:[a getLast]] == 3);
	[missing release];
	atomic_store(&probeDeallocs, 0);

	// removal releases, unless asked not to
	Probe* kept = [a getByIndex:1];
	[a remove:1 withRelease:NO];
	CHECK(atomic_load(&probeDeallocs) == 0);
	CHECK([kept value] == 2);
	[kept release];
	CHECK(atomic_load(&probeDeallocs) == 1);

	// a retained element survives its removal
	Probe* shared = [[a getFirst] retain];
	[a remove];
	CHECK(atomic_load(&probeDeallocs) == 1);
	CHECK([shared value] == 1);
	[shared release];
	CHECK(atomic_load(&probeDeallocs) == 2);

	// clear releases *every* element
	atomic_store(&probeDeallocs, 0);
	[a clear];
	CHECK(atomic_load(&probeDeallocs) == 2);
	atomic_store(&probeDeallocs, 0);
	for (int i = 0; i < 10; i++)
		[a push:probe(i)];
	[a clear];
	CHECK([a count] == 0);
	CHECK(atomic_load(&probeDeallocs) == 10);

	// clear:NO keeps the elements alive
	Probe* outside = probe(5);
	[a push:outside];
	[a clear:NO];
	CHECK([outside value] == 5);
	[outside release];

	// swap
	[a push:probe(1)];
	[a push:probe(2)];
	[a swap:0 to:1];
	CHECK([[a getFirst] value] == 2);
	[a clear];

	// sort: random data, strict and non-strict comparators
	srand(1234);
	for (int i = 0; i < 1000; i++)
		[a push:probe((Size)(rand() % 100))];
	[a sort:greater];
	BOOL sorted = YES;
	for (Size i = 1; i < [a count]; i++)
		if ([[a getByIndex:i - 1] value] > [[a getByIndex:i] value])
			sorted = NO;
	CHECK(sorted);
	[a sort:greaterOrEqual];
	sorted = YES;
	for (Size i = 1; i < [a count]; i++)
		if ([[a getByIndex:i - 1] value] > [[a getByIndex:i] value])
			sorted = NO;
	CHECK(sorted);
	[a clear];

	// sort is stable
	const Size values[] = { 30, 11, 20, 31, 12, 21, 32, 10 };
	for (int i = 0; i < 8; i++)
		[a push:probe(values[i])];
	[a sort:greaterByTens];
	const Size expected[] = { 11, 12, 10, 20, 21, 30, 31, 32 };
	for (Size i = 0; i < 8; i++)
		CHECK([[a getByIndex:i] value] == expected[i]);

	// already sorted input of any size is fine (no deep recursion)
	[a clear];
	for (Size i = 0; i < 100000; i++)
		[a push:probe(i)];
	[a sort:greater];
	CHECK([[a getLast] value] == 99999);

	atomic_store(&probeDeallocs, 0);
	[a release];
	CHECK(atomic_load(&probeDeallocs) == 100000);
}

// MARK: - File

static void testFile(void) {
	const char* path = "base_test_file.txt";
	const char* missing = "base_test_missing.txt";
	remove(path);
	remove(missing);

	File* file = [File new];

	// WRITE creates a new file
	[file open:BASE_FILE_WRITE withBuffer:path];
	CHECK([file isOpen]);
	CHECK([file writeBuffer:"hello"] == 5);
	CHECK([file close]);
	CHECK([File exist:path]);

	// APPEND
	[file open:BASE_FILE_APPEND withBuffer:path];
	String* tail = [[String alloc] initWithBuffer:" world"];
	CHECK([file writeString:tail] == 6);
	[tail release];
	[file close];

	// READ
	String* str = [String new];
	[file open:BASE_FILE_READ withBuffer:path];
	CHECK([file length] == 11);
	[file readWithString:str];
	CHECK([str compareBuffer:"hello world"]);

	// a stack buffer is never reallocated
	char buf[64];
	[file seek:6];
	CHECK([file position] == 6);
	CHECK([file readWithBuffer:buf size:32] == 5);
	CHECK(strcmp(buf, "world") == 0);
	CHECK([file readWithBuffer:buf size:32] == 0); // end of file
	CHECK(buf[0] == '\0');

	[file seekStart];
	[file readWithString:str size:5];
	CHECK([str compareBuffer:"hello"]);
	[file close];

	// READ|WRITE edits in place, AT_END starts at the end
	[file open:BASE_FILE_READ | BASE_FILE_WRITE withBuffer:path];
	[file writeBuffer:"J"];
	[file close];
	[file open:BASE_FILE_READ | BASE_FILE_AT_END withBuffer:path];
	CHECK([file position] == 11);
	[file seekStart];
	[file readWithString:str];
	CHECK([str compareBuffer:"Jello world"]);
	[file close];

	// binary read into a String is always terminated
	[file open:BASE_FILE_READ | BASE_FILE_BINARY withBuffer:path];
	[file readWithString:str];
	CHECK([str length] == 11);
	[file seekStart];
	memset(buf, 'x', sizeof(buf));
	CHECK([file readWithBuffer:buf size:5] == 5);
	CHECK(buf[5] == 'x'); // nothing appended in binary mode
	[file close];

	// errors are reported, not crashes
	CHECK_THROWS([file open:BASE_FILE_READ withBuffer:missing]);
	CHECK(![file isOpen]);
	CHECK_THROWS([file open:BASE_FILE_READ | BASE_FILE_WRITE
				 withBuffer:missing]);
	CHECK_THROWS([file open:BASE_FILE_NONE withBuffer:path]);
	CHECK_THROWS([file open:BASE_FILE_TRUNCATE withBuffer:path]);
	CHECK_THROWS([file readWithString:str]);
	CHECK_THROWS([file seek:0]);
	CHECK([file close]);
	CHECK(![File exist:missing]);

	[str release];
	[file release];
	remove(path);
}

// MARK: - Selector

static atomic_int classCalls = 0;

@interface Target : BaseObject
+ (id)classMethod;
- (id)echo:(id)arg;
@end
@implementation Target
+ (id)classMethod {
	atomic_fetch_add(&classCalls, 1);
	return nil;
}
- (id)echo:(id)arg {
	return arg;
}
@end

static void testSelector(void) {
	Target* t = [Target new];
	Number* n = [[Number alloc] initValue:7];

	CHECK([Selector perform:@selector(echo:) object:t argument:n] == n);

	// class methods
	atomic_store(&classCalls, 0);
	[Selector perform:@selector(classMethod) object:[Target class]];
	CHECK(atomic_load(&classCalls) == 1);

	Selector* sel = [[Selector new] setObject:t
								  setSelector:@selector(echo:)
								  setArgument:n];
	CHECK([sel perform] == n);
	CHECK([sel result] == n);
	[sel release];

	// unknown selectors throw instead of crashing
	CHECK_THROWS([Selector perform:@selector(classMethod) object:t]);
	CHECK_THROWS([Selector perform:@selector(echo:) object:[Target class]]);
	CHECK_THROWS([Selector perform:@selector(echo:) object:nil]);

	[n release];
	[t release];
}

// MARK: - Thread

static atomic_int workerDone = 0;

@interface Worker : BaseObject {
	atomic_int counter;
}
- (id)sum:(Array<Number*>*)args;
- (id)count:(Array*)args;
- (id)quit:(Array*)args;
- (int)counter;
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
- (id)quit:(Array*)args {
	[Thread exit:7];
	return nil; // unreachable
}
- (int)counter {
	return atomic_load(&counter);
}
@end

static void testThread(void) {
	Worker* w = [Worker new];

	// result and exit code
	Thread* t = [Thread new];
	Array<Number*>* args = [Array new];
	for (Size i = 1; i <= 10; i++)
		[args push:probe(i)];
	atomic_store(&probeDeallocs, 0);
	[t create:[[Selector new] setObject:w setSelector:@selector(sum:)]
		 args:args];
	Selector* extra = [Selector new];
	CHECK_THROWS([t create:extra]);
	[extra release];
	CHECK([t join] == 0);
	Number* sum = [t result];
	CHECK([sum value] == 55);
	[sum release];
	// arguments are released with the thread
	CHECK(atomic_load(&probeDeallocs) == 10);
	CHECK([t args] == nil);
	CHECK([t join] == 0); // joining twice is harmless

	// exit code from +exit:
	[t create:[[Selector new] setObject:w setSelector:@selector(quit:)]];
	CHECK([t join] == 7);

	// detach: the thread outlives the Thread object and frees its own
	// selector and arguments
	atomic_store(&workerDone, 0);
	atomic_store(&probeDeallocs, 0);
	Array* detachedArgs = [Array new];
	[detachedArgs push:probe(1)];
	[t create:[[Selector new] setObject:w setSelector:@selector(count:)]
		 args:detachedArgs];
	CHECK([t detach]);
	CHECK(![t detach]);
	[t release];
	for (int i = 0; i < 1000000 && atomic_load(&probeDeallocs) == 0; i++)
		[Thread yield];
	CHECK(atomic_load(&workerDone) == 1);
	CHECK(atomic_load(&probeDeallocs) == 1);

	// many threads, released (and joined) by the array
	Array<Thread*>* threads = [Array new];
	for (int i = 0; i < 8; i++) {
		Thread* th = [Thread new];
		[th create:[[Selector new] setObject:w setSelector:@selector(count:)]];
		[threads push:th];
	}
	[threads release];
	CHECK([w counter] == 9000);

	[w release];
}

int main(void) {
	testBaseObject();
	testString();
	testException();
	testArray();
	testFile();
	testSelector();
	testThread();

	printf("%d checks, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
