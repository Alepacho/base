// Exception and @try/@catch/@finally behaviour.

#include "unit.h"

@interface ParseError : Exception {
	int line;
}
- (id)initLine:(int)newLine;
- (int)line;
@end

@implementation ParseError
- (id)initLine:(int)newLine {
	self = [self initWithFormat:"parse error at line %i", newLine];
	if (self) line = newLine;
	return self;
}
- (int)line {
	return line;
}
@end

static void testMessages(void) {
	Exception* e = [Exception new];
	CHECK(strcmp([e message], "Unknown error") == 0);
	[e release];

	e = [[Exception alloc] initWithFormat:"%s", ""];
	CHECK(strcmp([e message], "Unknown error") == 0);
	[e release];

	e = [[Exception alloc] initWithFormat:"code %i in %s", 5, "test"];
	CHECK(strcmp([e message], "code 5 in test") == 0);
	[e release];

	String* msg = [[String alloc] initWithBuffer:"from string"];
	e = [[Exception alloc] initWithString:msg];
	[msg setBuffer:"changed"]; // the message is a copy
	CHECK(strcmp([e message], "from string") == 0);
	[e release];
	[msg release];

	e = [[Exception alloc] initWithString:nil];
	CHECK(strcmp([e message], "Unknown error") == 0);
	[e release];
}

static void testThrow(void) {
	Exception* thrown = [[Exception alloc] initWithFormat:"thrown"];
	Exception* caught = nil;
	BOOL finally = NO;
	@try {
		@throw thrown;
	} @catch (Exception* ex) {
		caught = ex;
	} @finally {
		finally = YES;
	}
	CHECK(caught == thrown);
	CHECK(finally);
	[caught release];

	// @finally also runs without an exception
	finally = NO;
	@try {
	} @finally {
		finally = YES;
	}
	CHECK(finally);

	// subclasses: the most specific handler wins
	BOOL specific = NO, generic = NO;
	@try {
		@throw [[ParseError alloc] initLine:3];
	} @catch (ParseError* pe) {
		specific = [pe line] == 3
				   && strcmp([pe message], "parse error at line 3") == 0;
		[pe release];
	} @catch (Exception* ex) {
		generic = YES;
		[ex release];
	}
	CHECK(specific);
	CHECK(!generic);

	// ...and a base class handler catches subclasses
	@try {
		@throw [[ParseError alloc] initLine:4];
	} @catch (Exception* ex) {
		generic = [ex isMemberOfClass:[ParseError class]];
		[ex release];
	}
	CHECK(generic);

	// rethrow keeps the same object and runs the inner @finally
	BOOL rethrown = NO;
	finally = NO;
	@try {
		@try {
			@throw [[Exception alloc] initWithFormat:"inner"];
		} @catch (Exception* ex) {
			@throw;
		} @finally {
			finally = YES;
		}
	} @catch (Exception* ex) {
		rethrown = strcmp([ex message], "inner") == 0;
		[ex release];
	}
	CHECK(rethrown);
	CHECK(finally);
}

// Errors reported by the library carry a useful message.
static void testLibraryMessages(void) {
	Array* a = [Array new];
	CHECK_THROWS_MESSAGE([a getByIndex:5], "Wrong array index '5'");
	CHECK_THROWS_MESSAGE([a push:nil], "NIL");
	[a release];

	File* f = [File new];
	CHECK_THROWS_MESSAGE([f open:BASE_FILE_READ withBuffer:"no_such_file.txt"],
						 "no_such_file.txt");
	CHECK_THROWS_MESSAGE([f open:BASE_FILE_TRUNCATE withBuffer:"x.txt"],
						 "invalid mode");
	CHECK_THROWS_MESSAGE([f seekEnd], "is not open");
	[f release];

	Number* n = [Number new];
	CHECK_THROWS_MESSAGE([Selector perform:@selector(nothing) object:n],
						 "'nothing'");
	[n release];
}

void testException(void) {
	testMessages();
	testThrow();
	testLibraryMessages();
}
