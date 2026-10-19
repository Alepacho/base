#include "base/file.h"
#include "base/exception.h"
#include "base/string.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if OS_WINDOWS
#include <io.h>
#define F_OK			 0
#define base_file_access _access
#define base_file_seek	 _fseeki64
#define base_file_tell	 _ftelli64
typedef __int64 base_file_offset;
#else
#include <sys/types.h>
#include <unistd.h>
#define base_file_access access
#define base_file_seek	 fseeko
#define base_file_tell	 ftello
typedef off_t base_file_offset;
#endif

static FILE* baseFileOpen(const char* name, const char* mode, int* err) {
	FILE* f = nil;
#if OS_WINDOWS
	*err = fopen_s(&f, name, mode);
#else
	errno = 0;
	f = fopen(name, mode);
	*err = errno;
#endif
	return f;
}

// See the mode table in file.h
static const char* baseFileModeString(BaseFileMode mode) {
	const BOOL binary = (mode & BASE_FILE_BINARY) != 0;
	const int m = mode
				  & (BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_APPEND
					 | BASE_FILE_TRUNCATE);

	switch (m) {
		case BASE_FILE_READ:
			return binary ? "rb" : "r";
		case BASE_FILE_WRITE:
		case BASE_FILE_WRITE | BASE_FILE_TRUNCATE:
			return binary ? "wb" : "w";
		case BASE_FILE_APPEND:
		case BASE_FILE_WRITE | BASE_FILE_APPEND:
			return binary ? "ab" : "a";
		case BASE_FILE_READ | BASE_FILE_WRITE:
			return binary ? "r+b" : "r+";
		case BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_TRUNCATE:
			return binary ? "w+b" : "w+";
		case BASE_FILE_READ | BASE_FILE_APPEND:
		case BASE_FILE_READ | BASE_FILE_WRITE | BASE_FILE_APPEND:
			return binary ? "a+b" : "a+";
		default:
			return nil;
	}
}

@implementation File

// @private

// Called first by every operation on the open file.
- (void)checkFile {
	if (![self isOpen])
		@throw [[Exception alloc]
			initWithFormat:"File '%s' is not open.", [path buffer]];

	// The error flag of a stream stays set: one failed operation would make
	// every later one fail too. errno is reset so that an error reports its
	// own cause, not the one of an earlier failure.
	clearerr(file);
	errno = 0;
}

- (void)throwError:(const char*)what {
	const int err = errno; // before anything else can overwrite it
	@throw [[Exception alloc]
		initWithFormat:"Failed to %s '%s' file: %s",
					   what,
					   [path buffer],
					   err ? strerror(err) : "unknown error"];
}

- (void)open {
	const char* m = baseFileModeString(mode);
	if (m == nil)
		@throw [[Exception alloc]
			initWithFormat:"Failed to open '%s' file: invalid mode 0x%x.",
						   [path buffer],
						   mode];

	int err = 0;
	file = baseFileOpen([path buffer], m, &err);
	if (file == nil) {
		@throw [[Exception alloc]
			initWithFormat:"Failed to open '%s' file with '%s' mode: %s",
						   [path buffer],
						   m,
						   strerror(err)];
	}

	if (mode & BASE_FILE_AT_END) [self seekEnd];
}

// Replaces the contents of `str` with up to `limit` bytes read from the
// current position.
- (void)read:(String*)str limit:(BaseSize)limit {
	[self checkFile];
	[str clear];

	char chunk[4096];
	BaseSize total = 0;
	while (total < limit) {
		const BaseSize left = limit - total;
		const size_t want = left < sizeof(chunk) ? (size_t)left : sizeof(chunk);
		const size_t got = fread(chunk, 1, want, file);
		[str appendBuffer:chunk length:got];
		total += got;
		if (got < want) break;
	}
	if (ferror(file)) [self throwError:"read"];
}

// @public

- (id)init {
	self = [super init];
	if (self) {
		file = nil;
		mode = BASE_FILE_NONE;
		@try {
			path = [String new];
		} @catch (id ex) {
			[self release];
			@throw;
		}
	}
	return self;
}

- (void)dealloc {
	[self close];

	[path release];
	[super dealloc];
}

+ (BOOL)exist:(const char*)pathName {
	if (pathName == nil) return NO;
	return base_file_access(pathName, F_OK) == 0;
}

- (BOOL)isOpen {
	return file != nil;
}

- (BaseSize)length {
	[self checkFile];

	const base_file_offset pos = base_file_tell(file);
	if (pos < 0) [self throwError:"get size of"];
	if (base_file_seek(file, 0, SEEK_END) != 0) [self throwError:"seek in"];
	const base_file_offset end = base_file_tell(file);
	const int tellError = errno;
	// always go back, then report what failed first
	if (base_file_seek(file, pos, SEEK_SET) != 0) [self throwError:"seek in"];
	if (end < 0) {
		errno = tellError;
		[self throwError:"get size of"];
	}

	return (BaseSize)end;
}

- (BaseSize)position {
	[self checkFile];

	const base_file_offset pos = base_file_tell(file);
	if (pos < 0) [self throwError:"get position in"];
	return (BaseSize)pos;
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

- (BOOL)close {
	if (![self isOpen]) return YES;

	// The stream is gone after fclose() whatever it returns.
	const BOOL result = fclose(file) != EOF;

	file = nil;
	mode = BASE_FILE_NONE;
	[path clear];

	return result;
}

- (void)seek:(BaseSize)pos {
	[self checkFile];
	if (base_file_seek(file, (base_file_offset)pos, SEEK_SET) != 0)
		[self throwError:"seek in"];
}

- (void)seekStart {
	[self seek:0];
}

- (void)seekEnd {
	[self checkFile];
	if (base_file_seek(file, 0, SEEK_END) != 0) [self throwError:"seek in"];
}

- (BaseSize)readWithBuffer:(char*)buf size:(BaseSize)size {
	[self checkFile];
	if (buf == nil)
		@throw [[Exception alloc] initWithFormat:"Unable to read file '%s'. %s",
												 [path buffer],
												 "Buffer is not defined!"];

	const BaseSize read = fread(buf, sizeof(char), size, file);
	if (read < size && ferror(file)) [self throwError:"read"];

	if (!(mode & BASE_FILE_BINARY)) buf[read] = '\0';
	return read;
}

- (void)readWithString:(String*)str {
	[self read:str limit:BASE_NOT_FOUND];
}

- (void)readWithString:(String*)str size:(BaseSize)size {
	[self read:str limit:size];
}

- (BaseSize)write:(const void*)data size:(BaseSize)size {
	[self checkFile];

	const BaseSize written = fwrite(data, 1, size, file);
	if (written < size) [self throwError:"write to"];
	return written;
}

- (BaseSize)writeBuffer:(const char*)buf {
	if (buf == nil) return 0;
	return [self write:buf size:strlen(buf)];
}

- (BaseSize)writeString:(String*)str {
	return [self writeBuffer:[str buffer]];
}

@end
