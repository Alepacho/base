#include "base/file.h"
#include "base/exception.h"
#include "base/string.h"
#include "base/system.h"

#include <stdio.h>
#include <stdlib.h>

#ifdef OS_WINDOWS
#include <io.h>
#define F_OK			 0
#define base_file_access _access
#else
#include <unistd.h>
#define base_file_access access

#endif

BOOL base_file_open(FILE** stream, const char* buf, const char* mode) {
	[System debug:"buf: %s", buf];
	[System debug:"mode: %s", mode];
	errno_t err = fopen_s(stream, buf, mode);
	return !err;
}

@implementation File

// @private

- (void)checkFile {
	if (![self isOpen])
		@throw [[Exception alloc] initWithFormat:"Unable to read '%s' file: %s",
												 [path buffer],
												 "File is not open."];
}

- (void)getFOpenMode:(String*)m {
	[m clear];

	if (mode & BASE_FILE_READ) [m appendBuffer:"r"];
	if (mode & BASE_FILE_WRITE) [m appendBuffer:"w"];
	if (mode & BASE_FILE_APPEND) [m appendBuffer:"a"];
	if (mode & BASE_FILE_BINARY) [m appendBuffer:"b"];

	// TODO: add + modes
}

- (void)open {
	if (![File exist:[path buffer]])
		@throw [[Exception alloc] initWithFormat:"Failed to open '%s' file: %s",
												 [path buffer],
												 "File not exist."];

	if (mode == BASE_FILE_NONE)
		@throw [[Exception alloc] initWithFormat:"Failed to open '%s' file: %s",
												 [path buffer],
												 "Mode is none."];

	String* m = [String new];
	[self getFOpenMode:m];

	if (!base_file_open((FILE**)&file, [path buffer], [m buffer])) {
		@throw [[Exception alloc]
			initWithFormat:"Failed to open '%s' file with '%s' mode: %s",
						   [path buffer],
						   [m buffer],
						   "File not exist or the mode is wrong."];
	}

	fseek(file, 0, SEEK_END);
	length = ftell(file);
	fseek(file, 0, SEEK_SET);

	[m dealloc];
}

// @public

- (id)init {
	self = [super init];
	if (self) {
		file = nil;
		mode = BASE_FILE_NONE;
		path = [String new];
		length = 0;
	}
	return self;
}

- (void)dealloc {
	[self close];

	[path dealloc];
	[super dealloc];
}

+ (BOOL)exist:(const char*)pathName {
	return base_file_access(pathName, F_OK) == 0;
}

- (BOOL)isOpen {
	return file != nil;
}

- (Size)length {
	return length;
}

- (void)open:(BaseFileMode)fileMode withBuffer:(const char*)pathName {
	[self close];
	mode = fileMode;
	[path setBuffer:pathName];
	[self open];
}

- (void)open:(BaseFileMode)fileMode withString:(String*)pathName {
	[self close];
	mode = fileMode;
	[path setString:pathName];
	[self open];
}

- (void)close {
	if (![self isOpen]) return;

	if (fclose(file) == EOF)
		@throw [[Exception alloc]
			initWithFormat:"Failed to close the file '%s'", [path buffer]];

	file = nil;
	mode = BASE_FILE_NONE;
	length = 0;

	[path clear];
}

- (void)seek:(Size)pos {
	[self checkFile];
	fseek(file, pos, SEEK_SET);
}

- (void)seekStart {
	[self checkFile];
	fseek(file, 0, SEEK_SET);
}

- (void)seekEnd {
	[self checkFile];
	fseek(file, 0, SEEK_END);
}

- (char*)readWithBuffer:(char*)buf size:(int)size {
	[self checkFile];
	char* res = fgets(buf, size, file);
	if (res == NULL) {
		@throw [[Exception alloc]
			initWithFormat:"Unable to read file '%s'.", [path buffer]];
	}
	return res;
}

- (void)readWithString:(String*)str size:(int)size {
	[self checkFile];
	char* buf = malloc(size + 1);
	if (fgets(buf, size + 1, file) == NULL) {
		free(buf);
		@throw [[Exception alloc]
			initWithFormat:"Unable to read file '%s'.", [path buffer]];
	}
	[str appendBuffer:buf];
	free(buf);
}

- (int)writeBuffer:(char*)buf {
	[self checkFile];
	return fputs(buf, file);
}

- (int)writeString:(String*)str {
	[self checkFile];
	return fputs([str buffer], file);
}

@end
