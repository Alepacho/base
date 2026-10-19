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

	CHECK(sizeof(BaseSize) == 8);
	CHECK(BASE_NOT_FOUND == (BaseSize)-1);
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

	n = [[Number alloc] initValue:(BaseSize)-1];
	CHECK([n value] == 18446744073709551615ULL);
	CHECK([n kind] == BASE_NUMBER_UNSIGNED);
	CHECK([n integer] == -1); // wraps around
	[n release];

	// signed
	n = [[Number alloc] initWithInteger:-5];
	CHECK([n kind] == BASE_NUMBER_SIGNED);
	CHECK([n integer] == -5);
	CHECK([n value] == (BaseSize)-5);
	CHECK([n real] == -5.0);
	[n release];

	// real: truncated towards zero and clamped, NaN is 0
	n = [[Number alloc] initWithReal:2.75];
	CHECK([n kind] == BASE_NUMBER_REAL);
	CHECK([n real] == 2.75);
	CHECK([n integer] == 2);
	CHECK([n value] == 2);
	[n setReal:-2.75];
	CHECK([n integer] == -2);
	CHECK([n value] == 0);
	[n setReal:1e300];
	CHECK([n integer] == LLONG_MAX);
	CHECK([n value] == SIZE_MAX);
	[n setReal:-1e300];
	CHECK([n integer] == LLONG_MIN);
	[n setReal:0.0 / 0.0];
	CHECK([n integer] == 0 && [n value] == 0);

	// setters change the kind
	CHECK([n setInteger:7] == n);
	CHECK([n kind] == BASE_NUMBER_SIGNED);
	CHECK([n set:8] == n);
	CHECK([n kind] == BASE_NUMBER_UNSIGNED);
	[n release];
}

static void testNumberObject(void) {
	Number* a = [[Number alloc] initWithInteger:3];
	Number* b = [[Number alloc] initWithInteger:3];
	Number* u = [[Number alloc] initValue:3];
	CHECK([a isEqual:b] && [a hash] == [b hash]);
	CHECK(![a isEqual:u]); // another kind
	CHECK(![a isEqual:nil]);
	String* s = [[String alloc] initWithBuffer:"3"];
	CHECK(![a isEqual:s]);
	[s release];

	Number* zero = [[Number alloc] initWithReal:0.0];
	Number* negativeZero = [[Number alloc] initWithReal:-0.0];
	CHECK([zero isEqual:negativeZero]);
	CHECK([zero hash] == [negativeZero hash]);

	Number* copy = [a copy];
	CHECK(copy != a && [copy isEqual:a]);
	[copy setInteger:4];
	CHECK([a integer] == 3);
	[copy release];

	String* d = [a copyDescription];
	CHECK([d compareBuffer:"3"]);
	[d release];
	d = [negativeZero copyDescription];
	CHECK([d compareBuffer:"-0"]);
	[d release];
	[u set:18446744073709551615ULL];
	d = [u copyDescription];
	CHECK([d compareBuffer:"18446744073709551615"]);
	[d release];

	[negativeZero release];
	[zero release];
	[u release];
	[b release];
	[a release];
}

@interface Plain : BaseObject
- (void)method;
+ (void)classMethod;
@end
@implementation Plain
- (void)method {
}
+ (void)classMethod {
}
@end

static void testIntrospection(void) {
	Bird* bird = [Bird new];

	CHECK([bird isKindOfClass:[Bird class]]);
	CHECK([bird isKindOfClass:[Animal class]]);
	CHECK([bird isKindOfClass:[BaseObject class]]);
	CHECK(![bird isKindOfClass:[Number class]]);
	CHECK([Bird isSubclassOfClass:[Animal class]]);
	CHECK([Bird isSubclassOfClass:[Bird class]]);
	CHECK(![Animal isSubclassOfClass:[Bird class]]);

	CHECK([bird respondsToSelector:@selector(legs)]);
	CHECK(![bird respondsToSelector:@selector(value)]);
	CHECK(![bird respondsToSelector:NULL]);
	CHECK([Bird instancesRespondToSelector:@selector(legs)]);
	CHECK(![Bird instancesRespondToSelector:@selector(classMethod)]);
	CHECK(![Bird instancesRespondToSelector:NULL]);
	// sent to a class: class methods
	CHECK([Plain respondsToSelector:@selector(classMethod)]);
	CHECK(![Plain respondsToSelector:@selector(method)]);

	[bird release];
}

static void testObjectDefaults(void) {
	Plain* a = [Plain new];
	Plain* b = [Plain new];

	// identity
	CHECK([a isEqual:a]);
	CHECK(![a isEqual:b]);
	CHECK(![a isEqual:nil]);
	CHECK([a hash] == [a hash]);

	CHECK_THROWS_MESSAGE([a copy], "can not be copied");

	String* d = [a copyDescription];
	char expected[64];
	snprintf(expected, sizeof(expected), "<Plain: %p>", (void*)a);
	CHECK([d compareBuffer:expected]);
	[d release];

	[b release];
	[a release];
}

void testBaseObject(void) {
	testPlatform();
	testClasses();
	testReferenceCounting();
	testNumber();
	testNumberObject();
	testIntrospection();
	testObjectDefaults();
}
