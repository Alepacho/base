// File. Test files are created in the working directory and removed after.

#include "unit.h"

static const char* path = "base_test_file.txt";
static const char* path2 = "base_test_file2.txt";
static const char* missing = "base_test_missing.txt";

static void writeFile(const char* name, const char* content) {
	FILE* f = fopen(name, "wb");
	fputs(content, f);
	fclose(f);
}

// Reads a whole file with plain stdio, independent of File.
static BOOL fileIs(const char* name, const char* expected) {
	char buf[256] = { 0 };
	FILE* f = fopen(name, "rb");
	if (f == NULL) return NO;
	const size_t read = fread(buf, 1, sizeof(buf) - 1, f);
	fclose(f);
	return read == strlen(expected) && memcmp(buf, expected, read) == 0;
}

static void cleanup(void) {
	remove(path);
	remove(path2);
	remove(missing);
}

static void testExist(void) {
	writeFile(path, "x");
	CHECK([File exist:path]);
	CHECK(![File exist:missing]);
	CHECK(![File exist:nil]);
	CHECK([File exist:"."]); // directories too
}

static void testModes(void) {
	File* file = [File new];
	CHECK(![file isOpen]);
	CHECK([file close]); // closing a closed file is fine

	// WRITE creates a file, WRITE and WRITE|TRUNCATE truncate it
	[file open:BASE_FILE_WRITE withBuffer:missing];
	CHECK([file isOpen]);
	CHECK([file writeBuffer:"hello"] == 5);
	CHECK([file close]);
	CHECK(![file isOpen]);
	CHECK(fileIs(missing, "hello"));
	remove(missing);

	writeFile(path, "old content");
	[file open:BASE_FILE_WRITE withBuffer:path];
	[file writeBuffer:"new"];
	[file close];
	CHECK(fileIs(path, "new"));
	[file open:BASE_FILE_WRITE | BASE_FILE_TRUNCATE withBuffer:path];
	[file close];
	CHECK(fileIs(path, ""));

	// APPEND and WRITE|APPEND create a file and write at its end
	[file open:BASE_FILE_APPEND withBuffer:missing];
	[file writeBuffer:"a"];
	[file close];
	CHECK(fileIs(missing, "a"));
	remove(missing);
	writeFile(path, "abc");
	[file open:BASE_FILE_WRITE | BASE_FILE_APPEND withBuffer:path];
	[file seekStart]; // writes still go to the end
	[file writeBuffer:"d"];
	[file close];
	CHECK(fileIs(path, "abcd"));

	// READ
	String* str = [String new];
	[file open:BASE_FILE_READ withBuffer:path];
	[file readWithString:str];
	CHECK([str compareBuffer:"abcd"]);
	[file close];

	// READ|WRITE edits an existing file in place
	[file open:BASE_FILE_READ | BASE_FILE_WRITE withBuffer:path];
	[file writeBuffer:"X"];
	[file seekStart]; // reposition between writing and reading
	[file readWithString:str];
	CHECK([str compareBuffer:"Xbcd"]);
	[file close];
	CHECK(fileIs(path, "Xbcd"));

	// READ|WRITE|TRUNCATE creates or empties, then reads back
	[file open:BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_TRUNCATE
		withBuffer:path];
	CHECK([file length] == 0);
	[file writeBuffer:"fresh"];
	[file seekStart];
	[file readWithString:str];
	CHECK([str compareBuffer:"fresh"]);
	[file close];

	// READ|APPEND and READ|WRITE|APPEND read anywhere, write at the end
	[file open:BASE_FILE_READ | BASE_FILE_APPEND withBuffer:path];
	[file seekStart];
	[file writeBuffer:"!"];
	[file seekStart];
	[file readWithString:str];
	CHECK([str compareBuffer:"fresh!"]);
	[file close];
	[file open:BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_APPEND
		withBuffer:missing];
	CHECK([file isOpen]);
	[file close];
	remove(missing);

	// AT_END starts at the end of the file
	[file open:BASE_FILE_READ | BASE_FILE_AT_END withBuffer:path];
	CHECK([file position] == 6);
	[file close];
	[file open:BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_AT_END
		withBuffer:path];
	[file writeBuffer:"?"];
	[file close];
	CHECK(fileIs(path, "fresh!?"));

	// open: with a String path
	String* name = [[String alloc] initWithBuffer:path];
	[file open:BASE_FILE_READ withString:name];
	CHECK([file isOpen]);
	[file readWithString:str];
	CHECK([str compareBuffer:"fresh!?"]);
	[name release];

	// opening again closes the previous file first
	writeFile(path2, "second");
	[file open:BASE_FILE_READ withBuffer:path2];
	[file readWithString:str];
	CHECK([str compareBuffer:"second"]);
	[file close];

	[str release];
	[file release];
}

static void testPositions(void) {
	writeFile(path, "hello world");

	File* file = [File new];
	[file open:BASE_FILE_READ withBuffer:path];
	CHECK([file length] == 11);
	CHECK([file position] == 0);

	[file seek:6];
	CHECK([file position] == 6);
	CHECK([file length] == 11); // length does not move the position
	CHECK([file position] == 6);

	[file seekEnd];
	CHECK([file position] == 11);
	[file seekStart];
	CHECK([file position] == 0);

	char buf[16];
	[file readWithBuffer:buf size:5];
	CHECK([file position] == 5);

	// past the end: nothing to read
	[file seek:100];
	CHECK([file readWithBuffer:buf size:5] == 0);
	[file close];

	// the length follows writes
	[file open:BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_TRUNCATE
		withBuffer:path];
	CHECK([file length] == 0);
	[file writeBuffer:"12345"];
	CHECK([file position] == 5);
	CHECK([file length] == 5);
	[file writeBuffer:"678"];
	CHECK([file length] == 8);
	[file close];

	[file release];
}

static void testRead(void) {
	writeFile(path, "hello world");

	File* file = [File new];
	String* str = [String new];
	char buf[64];

	[file open:BASE_FILE_READ withBuffer:path];

	// text mode: always NUL-terminated, never reallocated
	CHECK([file readWithBuffer:buf size:5] == 5);
	CHECK(strcmp(buf, "hello") == 0);
	CHECK([file readWithBuffer:buf size:32] == 6);
	CHECK(strcmp(buf, " world") == 0);
	CHECK([file readWithBuffer:buf size:32] == 0);
	CHECK(buf[0] == '\0');
	CHECK_THROWS([file readWithBuffer:nil size:4]);

	// readWithString: reads from the current position
	[file seek:6];
	[file readWithString:str];
	CHECK([str compareBuffer:"world"]);
	[file readWithString:str]; // at the end
	CHECK([str compareBuffer:""]);

	[file seekStart];
	[file readWithString:str size:5];
	CHECK([str compareBuffer:"hello"]);
	[file readWithString:str size:100]; // more than what is left
	CHECK([str compareBuffer:" world"]);
	[file close];

	// files bigger than the internal read chunk
	char big[10001];
	for (int i = 0; i < 10000; i++)
		big[i] = (char)('a' + i % 26);
	big[10000] = '\0';
	writeFile(path, big);
	[file open:BASE_FILE_READ withBuffer:path];
	[file readWithString:str];
	CHECK([str length] == 10000);
	CHECK([str compareBuffer:big]);
	[file close];

	[str release];
	[file release];
}

static void testBinary(void) {
	const char data[] = { 'a', '\0', 'b', '\n', '\r', (char)0xFF, 'c' };
	const Size size = sizeof(data);

	File* file = [File new];
	[file open:BASE_FILE_WRITE | BASE_FILE_BINARY withBuffer:path];
	CHECK([file write:data size:size] == size);
	CHECK([file write:data size:0] == 0);
	[file close];

	char buf[16];
	memset(buf, 'x', sizeof(buf));
	[file open:BASE_FILE_READ | BASE_FILE_BINARY withBuffer:path];
	CHECK([file length] == size);
	CHECK([file readWithBuffer:buf size:sizeof(buf)] == size);
	CHECK(memcmp(buf, data, size) == 0);
	CHECK(buf[size] == 'x'); // nothing appended in binary mode

	// a String stops at the first NUL but is always terminated
	String* str = [String new];
	[file seekStart];
	[file readWithString:str];
	CHECK([str compareBuffer:"a"]);
	[file seekStart];
	[file readWithString:str size:size];
	CHECK([str compareBuffer:"a"]);
	[file close];

	// writeString / writeBuffer
	[str setBuffer:"text"];
	[file open:BASE_FILE_WRITE withBuffer:path];
	CHECK([file writeString:str] == 4);
	CHECK([file writeBuffer:""] == 0);
	CHECK([file writeBuffer:nil] == 0);
	[file close];
	CHECK(fileIs(path, "text"));

	[str release];
	[file release];
}

static void testErrors(void) {
	File* file = [File new];
	String* str = [String new];
	char buf[8];

	// a closed file
	CHECK_THROWS([file length]);
	CHECK_THROWS([file position]);
	CHECK_THROWS([file seek:0]);
	CHECK_THROWS([file seekStart]);
	CHECK_THROWS([file seekEnd]);
	CHECK_THROWS([file readWithBuffer:buf size:4]);
	CHECK_THROWS([file readWithString:str]);
	CHECK_THROWS([file readWithString:str size:4]);
	CHECK_THROWS([file write:"x" size:1]);
	CHECK_THROWS([file writeBuffer:"x"]);
	CHECK_THROWS([file writeString:str]);

	// opening
	CHECK_THROWS_MESSAGE([file open:BASE_FILE_READ withBuffer:missing],
						 missing);
	CHECK(![file isOpen]);
	CHECK_THROWS([file open:BASE_FILE_READ | BASE_FILE_WRITE
				 withBuffer:missing]);
	CHECK(![File exist:missing]);
	CHECK_THROWS([file open:BASE_FILE_NONE withBuffer:path]);
	CHECK_THROWS([file open:BASE_FILE_BINARY withBuffer:path]);
	CHECK_THROWS([file open:BASE_FILE_TRUNCATE withBuffer:path]);
	CHECK_THROWS([file open:BASE_FILE_READ | BASE_FILE_TRUNCATE
				 withBuffer:path]);

	// a failed open closes the previously open file
	[file open:BASE_FILE_READ withBuffer:path];
	CHECK_THROWS([file open:BASE_FILE_READ withBuffer:missing]);
	CHECK(![file isOpen]);

	// wrong direction
	[file open:BASE_FILE_READ withBuffer:path];
	CHECK_THROWS([file writeBuffer:"x"]);
	[file close];
	[file open:BASE_FILE_WRITE withBuffer:path];
	CHECK_THROWS([file readWithBuffer:buf size:4]);
	[file close];

	[str release];
	[file release];
}

static void testDealloc(void) {
	// releasing an open file closes and flushes it
	File* file = [File new];
	[file open:BASE_FILE_WRITE withBuffer:path];
	[file writeBuffer:"flushed"];
	[file release];
	CHECK(fileIs(path, "flushed"));
}

void testFile(void) {
	cleanup();
	testExist();
	testModes();
	testPositions();
	testRead();
	testBinary();
	testErrors();
	testDealloc();
	cleanup();
}
