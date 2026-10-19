// Unit tests for base. Run with `ctest` (or the `base_tests` binary).
// Build with -DBASE_SANITIZE=ON to run them under ASan/UBSan.
//
// `base_tests <mode>` runs a scenario that terminates the process, its output
// is checked by ctest (see test/CMakeLists.txt).

#include "unit.h"

#include <signal.h>

static int checks = 0;
static int failures = 0;

void unitCheck(BOOL ok, const char* file, int line, const char* text) {
	checks++;
	if (!ok) {
		failures++;
		fprintf(stderr, "%s:%d: CHECK failed: %s\n", file, line, text);
	}
}

atomic_int probeDeallocs = 0;

@implementation Probe
- (void)dealloc {
	atomic_fetch_add(&probeDeallocs, 1);
	[super dealloc];
}
@end

Probe* probe(Size value) {
	return [[Probe alloc] initValue:value];
}

// The uncaught exception handler ends with abort(), which ctest always
// reports as a failure. Exit normally instead, ctest checks the output.
static void exitOnAbort(int sig) {
	(void)sig;
	_Exit(3);
}

static int runMode(const char* mode) {
	signal(SIGABRT, exitOnAbort);

	if (strcmp(mode, "fatal") == 0) {
		[System fatal:"bye %d", 42];
	} else if (strcmp(mode, "uncaught") == 0) {
		@throw [[Exception alloc] initWithFormat:"boom %d", 7];
	} else if (strcmp(mode, "uncaught-foreign") == 0) {
		@throw [Number new];
	} else {
		fprintf(stderr, "unknown mode '%s'\n", mode);
		return 2;
	}

	fprintf(stderr, "mode '%s' returned\n", mode);
	return 0;
}

int main(int argc, char** argv) {
	if (argc > 1) return runMode(argv[1]);

	testBaseObject();
	testString();
	testException();
	testArray();
	testFile();
	testSelector();
	testThread();
	testSystem(); // last: it redirects the standard streams

	printf("%d checks, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
