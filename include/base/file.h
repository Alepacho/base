#pragma once

#ifndef BASE_FILE_H
#define BASE_FILE_H

#include "base.h"

// Modes follow std::ios_base::openmode (BINARY may be added to any of them):
//   READ                    "r"   file must exist
//   WRITE, WRITE|TRUNCATE   "w"   create or truncate
//   WRITE|APPEND, APPEND    "a"   create, write at the end
//   READ|WRITE              "r+"  file must exist
//   READ|WRITE|TRUNCATE     "w+"  create or truncate
//   READ|APPEND (|WRITE)    "a+"  create, write at the end
// AT_END seeks to the end right after opening.
// Any other combination is rejected with an Exception.
// clang-format off
typedef enum {
    BASE_FILE_NONE     = 0x00,
    BASE_FILE_READ     = 0x01,
    BASE_FILE_WRITE    = 0x02,
    BASE_FILE_BINARY   = 0x04,
    BASE_FILE_AT_END   = 0x08,
    BASE_FILE_APPEND   = 0x10,
    BASE_FILE_TRUNCATE = 0x20,
} BaseFileMode;
// clang-format on

@class String;

// Every method except `isOpen`, `close` and `exist:` throws an Exception
// on failure.
@interface File : BaseObject {
	void* file;
	BaseFileMode mode;
	String* path;
}

- (id)init;
- (void)dealloc;

+ (BOOL)exist:(const char*)pathName;

- (void)open:(BaseFileMode)fileMode withBuffer:(const char*)pathName;
- (void)open:(BaseFileMode)fileMode withString:(String*)pathName;

- (BOOL)isOpen;
// Returns NO if pending data could not be written. The file is closed anyway.
- (BOOL)close;
// Current size of the file in bytes.
- (Size)length;
- (Size)position;

- (void)seek:(Size)pos;
- (void)seekStart;
- (void)seekEnd;

// Reads up to `size` bytes and returns how many were read (0 at the end of
// the file). In text mode `buf` must hold `size + 1` bytes and is always
// NUL-terminated; in binary mode nothing is appended.
- (Size)readWithBuffer:(char*)buf size:(Size)size;
// Replaces the contents of `str` with everything from the current position
// up to the end of the file. Binary data, NUL bytes included, is kept as is.
// If reading fails, `str` holds what was read before the error.
- (void)readWithString:(String*)str;
// Same, but reads up to `size` bytes.
- (void)readWithString:(String*)str size:(Size)size;

- (Size)write:(const void*)data size:(Size)size;
- (Size)writeBuffer:(const char*)buf;
- (Size)writeString:(String*)str;

@end

#endif // BASE_FILE_H
