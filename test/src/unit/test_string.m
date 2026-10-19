// String

#include "unit.h"

static String* makeString(const char* fmt, ...) BASE_FORMAT(1, 2);
static String* makeString(const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	String* s = [[String alloc] initWithFormat:fmt arguments:args];
	va_end(args);
	return s;
}

static void appendTo(String* s, const char* fmt, ...) BASE_FORMAT(2, 3);
static void appendTo(String* s, const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	[s appendFormat:fmt arguments:args];
	va_end(args);
}

static void setTo(String* s, const char* fmt, ...) BASE_FORMAT(2, 3);
static void setTo(String* s, const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	[s setFormat:fmt arguments:args];
	va_end(args);
}

static void testInit(void) {
	String* s = [String new];
	CHECK([s buffer] != nil);
	CHECK([s length] == 0);
	CHECK([s compareBuffer:""]);
	[s release];

	s = [[String alloc] init];
	CHECK([s length] == 0);
	[s release];

	s = [[String alloc] initWithBuffer:"abc"];
	CHECK([s compareBuffer:"abc"]);
	CHECK([s length] == 3);

	String* copy = [[String alloc] initWithString:s];
	CHECK([copy compareBuffer:"abc"]);
	CHECK([copy buffer] != [s buffer]); // a real copy
	[s setBuffer:"changed"];
	CHECK([copy compareBuffer:"abc"]);
	[copy release];
	[s release];

	s = [[String alloc] initWithBuffer:nil];
	CHECK([s compareBuffer:""]);
	[s release];

	s = [[String alloc] initWithString:nil];
	CHECK([s compareBuffer:""]);
	[s release];

	s = [[String alloc] initWithFormat:"%s=%i", "n", 7];
	CHECK([s compareBuffer:"n=7"]);
	[s release];

	s = makeString("%d|%s|%c", -5, "va", 'x');
	CHECK([s compareBuffer:"-5|va|x"]);
	[s release];
}

static void testCompare(void) {
	String* s = [[String alloc] initWithBuffer:"abc"];
	CHECK([s compareBuffer:"abc"]);
	CHECK(![s compareBuffer:"abcdef"]);
	CHECK(![s compareBuffer:"ab"]);
	CHECK(![s compareBuffer:"ABC"]);
	CHECK(![s compareBuffer:""]);
	CHECK(![s compareBuffer:nil]);
	[s release];

	String* empty = [String new];
	CHECK([empty compareBuffer:""]);
	CHECK(![empty compareBuffer:"anything"]);
	[empty release];
}

static void testAppend(void) {
	String* s = [[String alloc] initWithBuffer:"abc"];

	// empty appends are no-ops, not fatal errors
	CHECK([s appendBuffer:""] == s);
	CHECK([s appendBuffer:nil] == s);
	CHECK([s appendFormat:"%s", ""] == s);
	CHECK([s appendChar:'\0'] == s);
	CHECK([s compareBuffer:"abc"]);

	// chaining
	[[[s appendChar:'d'] appendFormat:"-%d-%s", 42, "x"] appendBuffer:"!"];
	CHECK([s compareBuffer:"abcd-42-x!"]);
	CHECK([s length] == 10);

	appendTo(s, "%%%u", 5u);
	CHECK([s compareBuffer:"abcd-42-x!%5"]);

	// growing well past the initial size
	[s clear];
	for (int i = 0; i < 10000; i++)
		[s appendChar:(char)('a' + i % 26)];
	CHECK([s length] == 10000);
	CHECK([s buffer][0] == 'a' && [s buffer][9999] == 'a' + 9999 % 26);

	[s release];
}

static void testSet(void) {
	String* s = [[String alloc] initWithBuffer:"abc"];

	CHECK([s setBuffer:"xyz"] == s);
	CHECK([s compareBuffer:"xyz"]);
	[s setBuffer:nil];
	CHECK([s compareBuffer:""]);

	CHECK([s setFormat:"%.2f", 1.5] == s);
	CHECK([s compareBuffer:"1.50"]);
	[s setFormat:"%llu", (Size)18446744073709551615ULL];
	CHECK([s compareBuffer:"18446744073709551615"]);
	setTo(s, "%s%s", "a", "b");
	CHECK([s compareBuffer:"ab"]);

	String* other = [[String alloc] initWithBuffer:"other"];
	CHECK([s setString:other] == s);
	CHECK([s compareBuffer:"other"]);
	[s setString:nil];
	CHECK([s compareBuffer:""]);
	[other release];

	[s setBuffer:"abc"];
	[s clear];
	CHECK([s length] == 0);
	CHECK([s compareBuffer:""]);

	[s release];
}

static void testAliasing(void) {
	String* s = [[String alloc] initWithBuffer:"abcd-42-x"];

	[s appendBuffer:[s buffer]];
	CHECK([s compareBuffer:"abcd-42-xabcd-42-x"]);
	[s appendBuffer:[s buffer] + 15];
	CHECK([s compareBuffer:"abcd-42-xabcd-42-x2-x"]);
	[s setBuffer:[s buffer] + 9];
	CHECK([s compareBuffer:"abcd-42-x2-x"]);
	[s setString:s];
	CHECK([s compareBuffer:"abcd-42-x2-x"]);

	// the buffer is writable
	[s buffer][0] = 'A';
	CHECK([s compareBuffer:"Abcd-42-x2-x"]);

	[s release];
}

static void testBinary(void) {
	const char data[] = { 'a', '\0', 'b' };

	String* s = [[String alloc] initWithBuffer:data length:3];
	CHECK([s length] == 3);
	CHECK(memcmp([s buffer], data, 3) == 0);
	CHECK([s buffer][3] == '\0');
	CHECK(![s compareBuffer:"a"]); // compared with its full length

	String* copy = [[String alloc] initWithString:s];
	CHECK([copy length] == 3);
	CHECK(memcmp([copy buffer], data, 3) == 0);

	[copy setString:nil];
	[copy appendBuffer:data length:3];
	[copy appendBuffer:"" length:0];
	[copy appendBuffer:nil length:5];
	[copy appendBuffer:data length:3];
	CHECK([copy length] == 6);
	CHECK(memcmp([copy buffer], "a\0ba\0b", 6) == 0);

	// appending itself, NULs included
	[copy appendBuffer:[copy buffer] length:[copy length]];
	CHECK([copy length] == 12);
	CHECK(memcmp([copy buffer] + 6, "a\0ba\0b", 6) == 0);
	[copy setBuffer:[copy buffer] + 2 length:2];
	CHECK([copy length] == 2);
	CHECK(memcmp([copy buffer], "ba", 2) == 0);
	[copy setBuffer:data length:1];
	CHECK([copy compareBuffer:"a"]);

	// formats can produce NULs too
	[copy setFormat:"%c%c", 'x', 0];
	CHECK([copy length] == 2);
	[copy appendFormat:"%c", 0];
	CHECK([copy length] == 3);

	[copy clear];
	CHECK([copy length] == 0);
	CHECK([copy buffer][0] == '\0');

	[copy release];
	[s release];
}

static void testGrowth(void) {
	// appending one byte at a time is linear: this would take minutes with
	// a strlen() and a realloc() per append
	String* s = [String new];
	for (int i = 0; i < 2000000; i++)
		[s appendChar:'x'];
	CHECK([s length] == 2000000);
	CHECK([s buffer][1999999] == 'x' && [s buffer][2000000] == '\0');
	[s release];
}

void testString(void) {
	testInit();
	testCompare();
	testAppend();
	testSet();
	testAliasing();
	testBinary();
	testGrowth();
}
