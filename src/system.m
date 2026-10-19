#include "base/system.h"

#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#if OS_WINDOWS
#define base_lock_file	 _lock_file
#define base_unlock_file _unlock_file
#else
#define base_lock_file	 flockfile
#define base_unlock_file funlockfile
#endif

// Writes one message while holding the stream lock, so that messages from
// several threads do not interleave. `prefix` and `suffix` may be NULL.
BASE_FORMAT(3, 0)
static void baseWrite(FILE* stream, const char* prefix, const char* fmt,
					  va_list args, const char* suffix) {
	base_lock_file(stream);
	if (prefix) fprintf(stream, "[%s]: ", prefix);
	vfprintf(stream, fmt, args);
	if (suffix) fputs(suffix, stream);
	base_unlock_file(stream);
}

#define BASE_WRITE(stream, prefix, fmt, suffix)                                \
	do {                                                                       \
		va_list args;                                                          \
		va_start(args, fmt);                                                   \
		baseWrite(stream, prefix, fmt, args, suffix);                          \
		va_end(args);                                                          \
	} while (0)

@implementation System

+ (void)debug:(const char*)fmt, ... {
	BASE_WRITE(stdout, NULL, fmt, "\n");
}

+ (void)trace:(const char*)fmt, ... {
	BASE_WRITE(stdout, NULL, fmt, "\n");
}

+ (void)warning:(const char*)fmt, ... {
	BASE_WRITE(stderr, "WARNING", fmt, "\n");
}

+ (void)error:(const char*)fmt, ... {
	BASE_WRITE(stderr, "ERROR", fmt, "\n");
}

+ (void)fatal:(const char*)fmt, ... {
	BASE_WRITE(stderr, "FATAL ERROR", fmt, "\n");
	exit(1);
}

+ (void)echo:(const char*)msg {
	if (msg) fputs(msg, stdout);
}

+ (void)print:(const char*)fmt, ... {
	BASE_WRITE(stdout, NULL, fmt, NULL);
}

+ (void)println:(const char*)fmt, ... {
	BASE_WRITE(stdout, NULL, fmt, "\n");
}

+ (int)input {
	return getchar();
}

+ (char*)input:(char*)buffer withLength:(size_t)length {
	// if (fgets(buffer, length, stdin) == NULL) {
	// 	@throw [[Exception alloc] initWithFormat:"Unable to get input buffer!"];
	// }
	if (length > INT_MAX) length = INT_MAX;
	return fgets(buffer, (int)length, stdin);
}

@end
