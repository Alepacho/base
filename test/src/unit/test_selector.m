// Selector

#include "unit.h"

static atomic_int classCalls = 0;
static atomic_int voidCalls = 0;

@interface Target : BaseObject
+ (id)classMethod;
+ (id)classEcho:(id)arg;
- (id)echo:(id)arg;
- (id)twice:(Number*)n;
- (id)itself;
- (id)countArgs:(Array*)args;
- (void)nothing;
- (void)take:(id)arg;
- (BOOL)flag;
- (int)number;
- (id)withInt:(int)value;
- (id)first:(id)a second:(id)b;
@end

static id taken = nil;

@implementation Target
+ (id)classMethod {
	atomic_fetch_add(&classCalls, 1);
	return self;
}
+ (id)classEcho:(id)arg {
	return arg;
}
- (id)echo:(id)arg {
	return arg;
}
- (id)twice:(Number*)n {
	[n set:[n value] * 2];
	return n;
}
- (id)itself {
	return self;
}
- (id)countArgs:(Array*)args {
	return [[Number alloc] initValue:[args count]];
}
- (void)nothing {
	atomic_fetch_add(&voidCalls, 1);
}
- (void)take:(id)arg {
	taken = arg;
}
- (BOOL)flag {
	return YES;
}
- (int)number {
	return 1;
}
- (id)withInt:(int)value {
	return nil;
}
- (id)first:(id)a second:(id)b {
	return a;
}
@end

@interface SubTarget : Target
@end
@implementation SubTarget
@end

static void testAccessors(void) {
	Selector* sel = [Selector new];
	CHECK([sel object] == nil);
	CHECK([sel selector] == NULL);
	CHECK([sel argument] == nil);
	CHECK([sel result] == nil);

	Target* t = [Target new];
	Number* n = [Number new];

	CHECK([sel setObject:t] == sel);
	CHECK([sel object] == t);
	CHECK([sel setSelector:@selector(echo:)] == sel);
	CHECK(sel_isEqual([sel selector], @selector(echo:)));
	CHECK([sel setArgument:n] == sel);
	CHECK([sel argument] == n);

	Target* other = [Target new];
	CHECK([sel setObject:other setSelector:@selector(itself)] == sel);
	CHECK([sel object] == other);
	CHECK(sel_isEqual([sel selector], @selector(itself)));
	CHECK([sel argument] == n); // untouched

	CHECK([sel setObject:t setSelector:@selector(twice:) setArgument:nil]
		  == sel);
	CHECK([sel object] == t);
	CHECK(sel_isEqual([sel selector], @selector(twice:)));
	CHECK([sel argument] == nil);

	[other release];
	[n release];
	[t release];
	[sel release];
}

static void testMethod(void) {
	Target* t = [Target new];

	const IMP echo = [Selector method:@selector(echo:) object:t];
	CHECK(echo != NULL);
	CHECK(
		echo
		== class_getMethodImplementation(object_getClass(t), @selector(echo:)));

	Selector* sel = [[Selector new] setObject:t setSelector:@selector(echo:)];
	CHECK([sel method] == echo);
	[sel release];

	// class objects resolve class methods
	const IMP classMethod = [Selector method:@selector(classMethod)
									  object:[Target class]];
	atomic_store(&classCalls, 0);
	CHECK(((id (*)(id, SEL))classMethod)([Target class], @selector(classMethod))
		  == [Target class]);
	CHECK(atomic_load(&classCalls) == 1);

	[t release];
}

static void testPerform(void) {
	Target* t = [Target new];
	Number* n = [[Number alloc] initValue:7];

	// instance methods
	CHECK([Selector perform:@selector(itself) object:t] == t);
	CHECK([Selector perform:@selector(echo:) object:t argument:n] == n);
	CHECK([Selector perform:@selector(echo:) object:t argument:nil] == nil);

	// class methods
	atomic_store(&classCalls, 0);
	CHECK([Selector perform:@selector(classMethod) object:[Target class]] ==
		  [Target class]);
	CHECK(atomic_load(&classCalls) == 1);
	CHECK([Selector perform:@selector(classEcho:)
					 object:[Target class]
				   argument:n]
		  == n);

	// inherited methods and methods of BaseObject itself
	SubTarget* sub = [SubTarget new];
	CHECK([Selector perform:@selector(itself) object:sub] == sub);
	CHECK([Selector perform:@selector(class) object:sub] == [SubTarget class]);
	[sub release];

	// void methods can be called and give nil
	atomic_store(&voidCalls, 0);
	CHECK([Selector perform:@selector(nothing) object:t] == nil);
	CHECK(atomic_load(&voidCalls) == 1);
	taken = nil;
	CHECK([Selector perform:@selector(take:) object:t argument:n] == nil);
	CHECK(taken == n);

	// a missing argument is nil, an extra one is ignored
	taken = t;
	[Selector perform:@selector(take:) object:t];
	CHECK(taken == nil);
	CHECK([Selector perform:@selector(itself) object:t argument:n] == t);

	// a configured Selector
	Selector* sel = [[Selector new] setObject:t
								  setSelector:@selector(twice:)
								  setArgument:n];
	CHECK([sel perform] == n);
	CHECK([n value] == 14);
	CHECK([sel result] == n);
	[sel perform];
	CHECK([n value] == 28);

	// perform: another selector with the same object and argument
	CHECK([sel perform:@selector(echo:)] == n);
	CHECK([sel result] == n);
	CHECK([sel perform:@selector(itself)] == t);
	CHECK([sel result] == t);
	CHECK(sel_isEqual([sel selector], @selector(twice:))); // unchanged

	// performWithArgs: passes the array as the argument
	Array* args = [Array new];
	[args push:probe(1)];
	[args push:probe(2)];
	[sel setSelector:@selector(countArgs:)];
	Number* count = [sel performWithArgs:args];
	CHECK([count value] == 2);
	CHECK([sel result] == count);
	[count release];
	[args release];

	[sel release];
	[n release];
	[t release];
}

static void testErrors(void) {
	Target* t = [Target new];

	CHECK_THROWS_MESSAGE([Selector perform:@selector(classMethod) object:t],
						 "'classMethod'");
	CHECK_THROWS_MESSAGE([Selector perform:@selector(echo:)
									object:[Target class]
								  argument:nil],
						 "'echo:'");
	CHECK_THROWS([Selector perform:@selector(echo:) object:nil]);
	CHECK_THROWS([Selector perform:NULL object:t]);

	// methods that can not be called through an `id` function pointer
	CHECK_THROWS_MESSAGE([Selector perform:@selector(flag) object:t],
						 "not an object");
	CHECK_THROWS_MESSAGE([Selector perform:@selector(number) object:t],
						 "not an object");
	CHECK_THROWS_MESSAGE([Selector perform:@selector(withInt:) object:t],
						 "argument");
	CHECK_THROWS_MESSAGE([Selector perform:@selector(first:second:)
									object:t
								  argument:t],
						 "takes 2 arguments");

	Selector* sel = [Selector new];
	CHECK_THROWS([sel perform]); // nothing set
	[sel setObject:t];
	CHECK_THROWS([sel perform]); // no selector
	CHECK_THROWS([sel perform:@selector(unknown)]);
	[sel release];

	[t release];
}

void testSelector(void) {
	testAccessors();
	testMethod();
	testPerform();
	testErrors();
}
