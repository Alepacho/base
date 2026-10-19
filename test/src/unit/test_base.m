// BaseObject, Number and the platform macros.

#include "unit.h"

@interface Animal : BaseObject {
	int legs;
}
- (id)init;
- (int)legs;
@end

@implementation Animal
- (id)init {
	self = [super init];
	if (self) legs = 4;
	return self;
}
- (int)legs {
	return legs;
}
@end

@interface Bird : Animal
@end

@implementation Bird
- (id)init {
	self = [super init];
	if (self) legs = 2;
	return self;
}
@end

static void testPlatform(void) {
	CHECK(OS_WINDOWS + OS_MACOS + OS_LINUX == 1);
#if defined(__APPLE__)
	CHECK(OS_MACOS);
#elif defined(_WIN32)
	CHECK(OS_WINDOWS);
#else
	CHECK(OS_LINUX);
#endif

	CHECK(sizeof(Size) == 8);
	CHECK(BASE_NOT_FOUND == (Size)-1);
}

static void testClasses(void) {
	Animal* animal = [[Animal alloc] init];
	Bird* bird = [Bird new];

	CHECK([Animal class] == [Animal class]);
	CHECK([Animal class] != [Bird class]);
	CHECK([animal class] == [Animal class]);
	CHECK([bird class] == [Bird class]);

	// init chains through the superclass
	CHECK([animal legs] == 4);
	CHECK([bird legs] == 2);

	CHECK([animal isMemberOfClass:[Animal class]]);
	CHECK(![animal isMemberOfClass:[Bird class]]);
	CHECK([bird isMemberOfClass:[Bird class]]);
	CHECK(![bird isMemberOfClass:[Animal class]]); // members only, not kinds

	CHECK([Bird isMemberOfClass:[Bird class]]);
	CHECK(![Bird isMemberOfClass:[Animal class]]);
	CHECK([Number isMemberOfClass:[Number class]]);
	CHECK(![Probe isMemberOfClass:[Number class]]);

	[bird release];
	[animal release];
}

static void testReferenceCounting(void) {
	atomic_store(&probeDeallocs, 0);

	Probe* p = probe(1);
	CHECK([p retain] == p);
	[p retain];
	[p retain];
	[p release];
	[p release];
	[p release];
	CHECK(atomic_load(&probeDeallocs) == 0);
	CHECK([p value] == 1);
	[p release];
	CHECK(atomic_load(&probeDeallocs) == 1);

	// autorelease, with nested pools
	atomic_store(&probeDeallocs, 0);
	@autoreleasepool {
		Probe* outer = probe(2);
		CHECK([outer autorelease] == outer);
		@autoreleasepool {
			[probe(3) autorelease];
		}
		CHECK(atomic_load(&probeDeallocs) == 1);
	}
	CHECK(atomic_load(&probeDeallocs) == 2);

	// an extra reference keeps an autoreleased object alive
	atomic_store(&probeDeallocs, 0);
	Probe* kept = probe(4);
	@autoreleasepool {
		[[kept retain] autorelease];
	}
	CHECK(atomic_load(&probeDeallocs) == 0);
	CHECK([kept value] == 4);
	[kept release];
	CHECK(atomic_load(&probeDeallocs) == 1);
}

static void testNumber(void) {
	Number* n = [Number new];
	CHECK([n value] == 0);
	CHECK([n set:42] == n);
	CHECK([n value] == 42);
	[n release];

	n = [[Number alloc] initValue:(Size)-1];
	CHECK([n value] == 18446744073709551615ULL);
	[n release];
}

void testBaseObject(void) {
	testPlatform();
	testClasses();
	testReferenceCounting();
	testNumber();
}
