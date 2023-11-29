#include "base/system.h"
#include "base/exception.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

@implementation System

+ (void)debug:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);
	fprintf(stdout, "\n");
}

+ (void)trace:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);
	fprintf(stdout, "\n");
}

+ (void)warning:(const char*)fmt, ... {
	fprintf(stderr, "[%s]: ", "WARNING");
	va_list args;
	va_start(args, fmt);
	vfprintf(stderr, fmt, args);
	va_end(args);
	fprintf(stderr, "\n");
}

+ (void)error:(const char*)fmt, ... {
	fprintf(stderr, "[%s]: ", "ERROR");
	va_list args;
	va_start(args, fmt);
	vfprintf(stderr, fmt, args);
	va_end(args);
	fprintf(stderr, "\n");
}

+ (void)fatal:(const char*)fmt, ... {
	fprintf(stderr, "[%s]: ", "FATAL ERROR");
	va_list args;
	va_start(args, fmt);
	vfprintf(stderr, fmt, args);
	va_end(args);
	fprintf(stderr, "\n");
	exit(1);
	// TODO: throw exception here?
}

+ (void)echo:(const char*)msg {
	printf("%s", msg);
}

+ (void)print:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);
}

+ (void)println:(const char*)fmt, ... {
	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);
	fprintf(stdout, "\n");
}

+ (char)input {
	return getchar();
}

+ (char*)input:(char*)buffer withLength:(size_t)length {
	// if (fgets(buffer, length, stdin) == NULL) {
	// 	@throw [[Exception alloc] initWithFormat:"Unable to get input buffer!"];
	// }
	return fgets(buffer, length, stdin);
}

@end
