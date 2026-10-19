// Array

#include "unit.h"

static BOOL greater(id a, id b) {
	return [(Number*)a value] > [(Number*)b value];
}

static BOOL greaterOrEqual(id a, id b) {
	return [(Number*)a value] >= [(Number*)b value];
}

static BOOL less(id a, id b) {
	return [(Number*)a value] < [(Number*)b value];
}

// Sort key is value / 10, the last digit records the original order.
static BOOL greaterByTens(id a, id b) {
	return [(Number*)a value] / 10 > [(Number*)b value] / 10;
}

// Checks that `a` holds exactly `count` values from `values`.
static BOOL holds(Array<Number*>* a, const BaseSize* values, BaseSize count) {
	if ([a count] != count) return NO;
	for (BaseSize i = 0; i < count; i++)
		if ([[a getByIndex:i] value] != values[i]) return NO;
	return YES;
}

static BOOL isSorted(Array<Number*>* a) {
	for (BaseSize i = 1; i < [a count]; i++)
		if ([[a getByIndex:i - 1] value] > [[a getByIndex:i] value]) return NO;
	return YES;
}

static void testCapacity(void) {
	Array* a = [Array new];
	CHECK([a count] == 0);
	CHECK([a size] == 0);
	[a release];

	a = [[Array alloc] initWithSize:16];
	CHECK([a count] == 0);
	CHECK([a size] == 16);
	for (BaseSize i = 0; i < 16; i++)
		[a push:probe(i)];
	CHECK([a size] == 16); // no reallocation while it fits
	[a push:probe(16)];
	CHECK([a count] == 17);
	CHECK([a size] > 16);
	[a clear];
	CHECK([a count] == 0);
	CHECK([a size] == 0);
	[a push:probe(1)]; // usable after clear
	CHECK([a count] == 1);
	[a release];

	// sizes whose byte count does not fit in memory, even after wrapping
	CHECK_THROWS_MESSAGE([[Array alloc] initWithSize:(BaseSize)1 << 61],
						 "Out of memory");
	CHECK_THROWS_MESSAGE([[Array alloc] initWithSize:BASE_NOT_FOUND],
						 "Out of memory");

	a = [[Array alloc] initWithSize:0];
	CHECK([a size] == 0);
	[a push:probe(1)];
	CHECK([a count] == 1);
	[a release];
}

static void testAccess(void) {
	Array<Probe*>* a = [Array new];
	CHECK([a getFirst] == nil);
	CHECK([a getLast] == nil);
	CHECK_THROWS([a getByIndex:0]);

	Probe* first = probe(1);
	CHECK([a push:first] == first);
	[a push:probe(2)];
	[a push:probe(3)];
	CHECK([a getFirst] == first);
	CHECK([[a getLast] value] == 3);
	CHECK([[a getByIndex:1] value] == 2);
	CHECK_THROWS([a getByIndex:3]);
	CHECK_THROWS([a getByIndex:BASE_NOT_FOUND]);

	CHECK([a getIndexByObject:first] == 0);
	CHECK([a getIndexByObject:[a getLast]] == 2);
	CHECK([a getIndexByObject:nil] == BASE_NOT_FOUND);
	Probe* missing = probe(0);
	CHECK([a getIndexByObject:missing] == BASE_NOT_FOUND);
	[missing release];

	// the same object twice: the first index is found
	[a push:[first retain]];
	CHECK([a getIndexByObject:first] == 0);

	[a release];
}

static void testInsert(void) {
	Array<Probe*>* a = [Array new];

	// into an empty array, at the beginning, in the middle and at the end
	[a insert:probe(2)];
	[a insert:probe(4) byIndex:1];
	[a insert:probe(1)];
	[a insert:probe(3) byIndex:2];
	const BaseSize expected[] = { 1, 2, 3, 4 };
	CHECK(holds(a, expected, 4));

	// ownership is only transferred on success
	atomic_store(&probeDeallocs, 0);
	Probe* rejected = probe(9);
	CHECK_THROWS([a insert:rejected byIndex:10]);
	CHECK_THROWS([a insert:nil]);
	CHECK_THROWS([a push:nil]);
	CHECK(atomic_load(&probeDeallocs) == 0);
	[rejected release];
	[a clear];

	// many inserts at the front grow the storage and keep the order
	for (BaseSize i = 0; i < 1000; i++)
		[a insert:probe(i)];
	CHECK([a count] == 1000);
	CHECK([[a getFirst] value] == 999);
	CHECK([[a getLast] value] == 0);

	[a release];
}

static void testRemove(void) {
	Array<Probe*>* a = [Array new];
	[a pop]; // no-op on empty
	CHECK_THROWS([a remove]);
	CHECK_THROWS([a remove:0]);

	for (BaseSize i = 1; i <= 5; i++)
		[a push:probe(i)];

	atomic_store(&probeDeallocs, 0);
	[a pop];
	const BaseSize afterPop[] = { 1, 2, 3, 4 };
	CHECK(holds(a, afterPop, 4));
	CHECK(atomic_load(&probeDeallocs) == 1);

	[a remove];
	const BaseSize afterRemove[] = { 2, 3, 4 };
	CHECK(holds(a, afterRemove, 3));
	CHECK(atomic_load(&probeDeallocs) == 2);

	[a remove:1];
	const BaseSize afterRemoveAt[] = { 2, 4 };
	CHECK(holds(a, afterRemoveAt, 2));
	CHECK(atomic_load(&probeDeallocs) == 3);
	CHECK_THROWS([a remove:2]);

	// removal without release hands the element back to the caller
	Probe* kept = [a getLast];
	[a remove:1 withRelease:NO];
	CHECK(atomic_load(&probeDeallocs) == 3);
	CHECK([kept value] == 4);
	[kept release];
	CHECK(atomic_load(&probeDeallocs) == 4);

	// a retained element survives its removal
	Probe* shared = [[a getFirst] retain];
	[a remove:0 withRelease:YES];
	CHECK([a count] == 0);
	CHECK(atomic_load(&probeDeallocs) == 4);
	CHECK([shared value] == 2);
	[shared release];
	CHECK(atomic_load(&probeDeallocs) == 5);

	// clear releases *every* element, clear:NO none of them
	for (int i = 0; i < 10; i++)
		[a push:probe(i)];
	atomic_store(&probeDeallocs, 0);
	[a clear];
	CHECK([a count] == 0);
	CHECK(atomic_load(&probeDeallocs) == 10);
	[a clear]; // clearing an empty array is fine

	Probe* outside = probe(5);
	[a push:outside];
	[a clear:NO];
	CHECK([a count] == 0);
	CHECK(atomic_load(&probeDeallocs) == 10);
	CHECK([outside value] == 5);
	[outside release];

	[a push:probe(6)];
	[a clear:YES];
	CHECK(atomic_load(&probeDeallocs) == 12);

	[a release];
}

static void testSwap(void) {
	Array<Probe*>* a = [Array new];
	CHECK_THROWS([a swap:0 to:0]);
	for (BaseSize i = 1; i <= 3; i++)
		[a push:probe(i)];

	[a swap:0 to:2];
	const BaseSize swapped[] = { 3, 2, 1 };
	CHECK(holds(a, swapped, 3));
	[a swap:1 to:1];
	CHECK(holds(a, swapped, 3));
	CHECK_THROWS([a swap:0 to:3]);
	CHECK_THROWS([a swap:3 to:0]);

	[a release];
}

static void testSort(void) {
	Array<Probe*>* a = [Array new];
	CHECK([a sort:greater] == a); // empty
	[a push:probe(1)];
	CHECK([a sort:greater] == a); // single element
	CHECK([[a getFirst] value] == 1);
	[a clear];

	// random data, strict and non-strict comparators, both directions
	srand(1234);
	for (int i = 0; i < 1000; i++)
		[a push:probe((BaseSize)(rand() % 100))];
	[a sort:greater];
	CHECK(isSorted(a));
	[a sort:less];
	CHECK([[a getFirst] value] >= [[a getLast] value]);
	BOOL descending = YES;
	for (BaseSize i = 1; i < [a count]; i++)
		if ([[a getByIndex:i - 1] value] < [[a getByIndex:i] value])
			descending = NO;
	CHECK(descending);
	[a sort:greaterOrEqual];
	CHECK(isSorted(a));
	CHECK([a count] == 1000);
	[a clear];

	// stable
	const BaseSize values[] = { 30, 11, 20, 31, 12, 21, 32, 10 };
	for (int i = 0; i < 8; i++)
		[a push:probe(values[i])];
	[a sort:greaterByTens];
	const BaseSize stable[] = { 11, 12, 10, 20, 21, 30, 31, 32 };
	CHECK(holds(a, stable, 8));
	[a clear];

	// already sorted and reversed input of any size (no deep recursion)
	for (BaseSize i = 0; i < 100000; i++)
		[a push:probe(i)];
	[a sort:greater];
	CHECK([[a getLast] value] == 99999);
	[a sort:less];
	CHECK([[a getFirst] value] == 99999);
	[a sort:greater];
	CHECK(isSorted(a));

	atomic_store(&probeDeallocs, 0);
	[a release];
	CHECK(atomic_load(&probeDeallocs) == 100000);
}

static void testContents(void) {
	// any object type, arrays of arrays release recursively
	atomic_store(&probeDeallocs, 0);
	Array* outer = [Array new];
	for (int i = 0; i < 3; i++) {
		Array<Probe*>* inner = [Array new];
		[inner push:probe(1)];
		[inner push:probe(2)];
		[outer push:inner];
	}
	[outer push:[[String alloc] initWithBuffer:"mixed"]];
	CHECK([outer count] == 4);
	CHECK([[outer getByIndex:1] count] == 2);
	[outer release];
	CHECK(atomic_load(&probeDeallocs) == 6);
}

static void testObject(void) {
	Array* a = [Array new];
	Array* b = [Array new];
	CHECK([a isEqual:b] && [a hash] == [b hash]); // both empty

	for (BaseSize i = 0; i < 3; i++) {
		[a push:probe(i)];
		[b push:probe(i)];
	}
	CHECK([a isEqual:b] && [a hash] == [b hash]);
	CHECK(![a isEqual:nil]);
	[b swap:0 to:1];
	CHECK(![a isEqual:b]); // order matters
	[b pop];
	CHECK(![a isEqual:b]);

	// equal objects, not only the same ones
	Number* two = [[Number alloc] initValue:2];
	CHECK([a getIndexByObject:two] == BASE_NOT_FOUND);
	CHECK([a getIndexByEqualObject:two] == 2);
	CHECK([a getIndexByEqualObject:nil] == BASE_NOT_FOUND);
	[two set:9];
	CHECK([a getIndexByEqualObject:two] == BASE_NOT_FOUND);
	[two release];

	// a copy shares the elements
	atomic_store(&probeDeallocs, 0);
	Array* copy = [a copy];
	CHECK([copy isEqual:a]);
	CHECK([copy getFirst] == [a getFirst]);
	[a release];
	CHECK(atomic_load(&probeDeallocs) == 0); // still held by the copy
	CHECK([[copy getLast] value] == 2);

	String* d = [copy copyDescription];
	CHECK([d compareBuffer:"[0, 1, 2]"]);
	[d release];
	[copy push:[[String alloc] initWithBuffer:"text"]];
	[copy push:[Array new]];
	d = [copy copyDescription];
	CHECK([d compareBuffer:"[0, 1, 2, text, []]"]);
	[d release];

	[copy release];
	CHECK(atomic_load(&probeDeallocs) == 3);
	[b release];
}

void testArray(void) {
	testCapacity();
	testAccess();
	testInsert();
	testRemove();
	testSwap();
	testSort();
	testContents();
	testObject();
}
