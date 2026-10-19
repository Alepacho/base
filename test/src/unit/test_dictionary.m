// Dictionary

#include "unit.h"

static String* str(const char* s) {
	return [[String alloc] initWithBuffer:s];
}

// Value stored for the String key `s`, without taking over anything.
static id lookup(Dictionary* d, const char* s) {
	String* key = str(s);
	id value = [d get:key];
	[key release];
	return value;
}

static void testBasics(void) {
	Dictionary<String*, Probe*>* d = [Dictionary new];
	CHECK([d count] == 0);
	CHECK(lookup(d, "a") == nil);
	CHECK([d get:nil] == nil);
	CHECK(![d has:nil]);
	CHECK(![d remove:nil]);

	Probe* one = probe(1);
	[d set:one forKey:str("one")];
	[d set:probe(2) forKey:str("two")];
	CHECK([d count] == 2);
	CHECK(lookup(d, "one") == one); // found with another, equal String
	CHECK([lookup(d, "two") value] == 2);
	CHECK(lookup(d, "three") == nil);

	String* key = str("one");
	CHECK([d has:key]);
	CHECK([d remove:key]);
	CHECK(![d has:key]);
	CHECK(![d remove:key]);
	CHECK([d count] == 1);
	[key release];

	// nil is rejected and nothing is taken over
	atomic_store(&probeDeallocs, 0);
	Probe* value = probe(3);
	key = str("k");
	CHECK_THROWS_MESSAGE([d set:nil forKey:key], "NIL");
	CHECK_THROWS_MESSAGE([d set:value forKey:nil], "NIL");
	CHECK([d count] == 1);
	CHECK(atomic_load(&probeDeallocs) == 0);
	[value release];
	[key release];

	// Number keys, mixed with String ones
	[d set:probe(4) forKey:(id)[[Number alloc] initValue:10]];
	Number* ten = [[Number alloc] initValue:10];
	CHECK([[d get:(id)ten] value] == 4);
	[ten setInteger:10];
	CHECK([d get:(id)ten] == nil); // another kind of Number
	[ten release];

	[d release];
}

static void testOwnership(void) {
	Dictionary<String*, Probe*>* d = [Dictionary new];
	atomic_store(&probeDeallocs, 0);

	// replacing a value releases the old one and the new key
	String* stored = str("k");
	[d set:probe(1) forKey:[stored retain]];
	String* again = str("k");
	[again retain];
	[d set:probe(2) forKey:again];
	CHECK(atomic_load(&probeDeallocs) == 1);
	CHECK([lookup(d, "k") value] == 2);
	[again release]; // our own reference is the last one now

	// setting the same value again keeps it alive
	Probe* same = [d get:stored];
	[d set:[same retain] forKey:[stored retain]];
	CHECK(atomic_load(&probeDeallocs) == 1);
	CHECK([d get:stored] == same && [same value] == 2);

	// remove and clear release keys and values
	[d set:probe(3) forKey:str("x")];
	CHECK([d remove:stored]);
	CHECK(atomic_load(&probeDeallocs) == 2);
	[stored release];
	[d clear];
	CHECK([d count] == 0);
	CHECK(atomic_load(&probeDeallocs) == 3);
	[d clear];

	// and so does the dictionary itself
	for (int i = 0; i < 10; i++) {
		[d set:probe(i) forKey:(id)[[Number alloc] initValue:i]];
	}
	[d release];
	CHECK(atomic_load(&probeDeallocs) == 13);
}

// Many insertions and removals, checked against a plain array.
static void testStress(void) {
	enum {
		N = 20000
	};
	static BOOL present[N];
	memset(present, 0, sizeof(present));

	Dictionary<Number*, Number*>* d = [[Dictionary alloc] initWithSize:16];
	srand(42);
	BaseSize expected = 0;
	for (int step = 0; step < 200000; step++) {
		const int k = rand() % N;
		Number* key = [[Number alloc] initValue:(BaseSize)k];
		if (rand() % 3 == 0) {
			const BOOL removed = [d remove:key];
			if (removed != present[k]) {
				CHECK(removed == present[k]);
				break;
			}
			if (removed) expected--;
			present[k] = NO;
			[key release];
		} else {
			if (!present[k]) expected++;
			present[k] = YES;
			[d set:[[Number alloc] initValue:(BaseSize)k * 2] forKey:key];
		}
	}
	CHECK([d count] == expected);

	BOOL ok = YES;
	for (int k = 0; k < N && ok; k++) {
		Number* key = [[Number alloc] initValue:(BaseSize)k];
		Number* value = [d get:key];
		ok = present[k] ? (value != nil && [value value] == (BaseSize)k * 2)
						: value == nil;
		[key release];
	}
	CHECK(ok);

	Array* keys = [d copyKeys];
	Array* values = [d copyValues];
	CHECK([keys count] == expected && [values count] == expected);
	ok = YES;
	for (BaseSize i = 0; i < [keys count] && ok; i++) {
		ok = [[values getByIndex:i] value] == [[keys getByIndex:i] value] * 2;
	}
	CHECK(ok); // same order
	[values release];
	[keys release];

	[d release];
}

// Keys whose hashes all collide still work.
@interface SameHash : Number
@end
@implementation SameHash
- (BaseSize)hash {
	return 7;
}
@end

static void testCollisions(void) {
	Dictionary* d = [Dictionary new];
	for (BaseSize i = 0; i < 100; i++) {
		[d set:[[Number alloc] initValue:i]
			forKey:[[SameHash alloc] initValue:i]];
	}
	BOOL ok = YES;
	for (BaseSize i = 0; i < 100; i += 2) {
		SameHash* key = [[SameHash alloc] initValue:i];
		ok = ok && [d remove:key];
		[key release];
	}
	for (BaseSize i = 0; i < 100; i++) {
		SameHash* key = [[SameHash alloc] initValue:i];
		Number* value = [d get:key];
		ok = ok && ((i % 2 == 0) ? value == nil : [value value] == i);
		[key release];
	}
	CHECK(ok);
	CHECK([d count] == 50);
	[d release];
}

static void testObject(void) {
	Dictionary* a = [Dictionary new];
	Dictionary* b = [Dictionary new];
	CHECK([a isEqual:b] && [a hash] == [b hash]);

	[a set:str("1") forKey:str("one")];
	[a set:str("2") forKey:str("two")];
	// inserted in another order
	[b set:str("2") forKey:str("two")];
	[b set:str("1") forKey:str("one")];
	CHECK([a isEqual:b] && [a hash] == [b hash]);
	CHECK(![a isEqual:nil]);

	[b set:str("other") forKey:str("two")];
	CHECK(![a isEqual:b]);

	Dictionary* copy = [a copy];
	CHECK([copy isEqual:a]);
	String* key = str("one");
	CHECK([copy get:key] == [a get:key]); // shared values
	[key release];
	[a clear];
	CHECK([copy count] == 2);

	Dictionary* single = [Dictionary new];
	[single set:[[Number alloc] initWithInteger:-1] forKey:str("n")];
	String* d = [single copyDescription];
	CHECK([d compareBuffer:"{n: -1}"]);
	[d release];
	[single clear];
	d = [single copyDescription];
	CHECK([d compareBuffer:"{}"]);
	[d release];

	[single release];
	[copy release];
	[b release];
	[a release];
}

static void testCapacity(void) {
	CHECK_THROWS_MESSAGE([[Dictionary alloc] initWithSize:BASE_NOT_FOUND],
						 "Out of memory");

	Dictionary* d = [[Dictionary alloc] initWithSize:1000];
	for (BaseSize i = 0; i < 1000; i++) {
		[d set:[Number new] forKey:[[Number alloc] initValue:i]];
	}
	CHECK([d count] == 1000);
	[d release];
}

void testDictionary(void) {
	testBasics();
	testOwnership();
	testStress();
	testCollisions();
	testObject();
	testCapacity();
}
