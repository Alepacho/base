// System. The standard streams are redirected to temporary files.
// `+fatal:` terminates the process and is tested as a separate ctest test.

#include "unit.h"

#if OS_WINDOWS
#include <io.h>
#define base_dup	_dup
#define base_dup2	_dup2
#define base_close	_close
#define base_fileno _fileno
#else
#include <unistd.h>
#define base_dup	dup
#define base_dup2	dup2
#define base_close	close
#define base_fileno fileno
#endif

static const char* capturePath = "base_test_capture.txt";
static int savedFd = -1;

static void redirect(FILE* stream, const char* name, const char* mode) {
	fflush(stream);
	savedFd = base_dup(base_fileno(stream));
	FILE* f = fopen(name, mode);
	base_dup2(base_fileno(f), base_fileno(stream));
	fclose(f);
	clearerr(stream);
}

static void restore(FILE* stream) {
	fflush(stream);
	base_dup2(savedFd, base_fileno(stream));
	base_close(savedFd);
	savedFd = -1;
	clearerr(stream);
}

static void captureBegin(FILE* stream) {
	redirect(stream, capturePath, "w");
}

// Returns YES when everything written to `stream` since captureBegin()
// equals `expected`.
static BOOL captureEnd(FILE* stream, const char* expected) {
	restore(stream);

	char buf[256] = { 0 };
	FILE* f = fopen(capturePath, "r");
	const size_t read = fread(buf, 1, sizeof(buf) - 1, f);
	fclose(f);
	remove(capturePath);

	const BOOL ok = strcmp(buf, expected) == 0;
	if (!ok) fprintf(stderr, "captured '%.*s'\n", (int)read, buf);
	return ok;
}

static void testOutput(void) {
	captureBegin(stdout);
	[System debug:"debug %d", 1];
	[System trace:"trace %s", "two"];
	[System print:"print %c", '3'];
	[System print:"%s", ""];
	[System println:" println %u", 4u];
	[System echo:"echo %d raw\n"]; // not a format
	CHECK(captureEnd(stdout,
					 "debug 1\ntrace two\nprint 3 println 4\necho %d raw\n"));

	captureBegin(stderr);
	[System warning:"careful %d", 5];
	[System error:"broken %s", "six"];
	CHECK(captureEnd(stderr, "[WARNING]: careful 5\n[ERROR]: broken six\n"));
}

static void testInput(void) {
	FILE* f = fopen(capturePath, "w");
	fputs("xy\nhello world\nabcdef\nlast", f);
	fclose(f);

	char buf[64];
	redirect(stdin, capturePath, "r");

	const int x = [System input];
	const int y = [System input];
	const int newline = [System input];

	char* line = [System input:buf withLength:sizeof(buf)];
	const BOOL gotLine = line == buf && strcmp(buf, "hello world\n") == 0;

	// the length includes the terminating NUL
	[System input:buf withLength:4];
	const BOOL gotShort = strcmp(buf, "abc") == 0;
	[System input:buf withLength:sizeof(buf)]; // rest of the line

	[System input:buf withLength:sizeof(buf)];
	const BOOL gotLast = strcmp(buf, "last") == 0;

	char* end = [System input:buf withLength:sizeof(buf)];
	const int eof = [System input];

	restore(stdin);
	remove(capturePath);

	CHECK(x == 'x');
	CHECK(y == 'y');
	CHECK(newline == '\n');
	CHECK(gotLine);
	CHECK(gotShort);
	CHECK(gotLast);
	CHECK(end == NULL);
	CHECK(eof == EOF);
}

void testSystem(void) {
	testOutput();
	testInput();
}
