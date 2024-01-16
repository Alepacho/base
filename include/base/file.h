#pragma once

#ifndef BASE_FILE_H
#define BASE_FILE_H

#include "base.h"

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

@interface File : BaseObject {
	void* file;
	BaseFileMode mode;
	String* path;
	Size length;
}

- (id)init;
- (void)dealloc;

+ (BOOL)exist:(const char*)pathName;

- (void)open:(BaseFileMode)fileMode withBuffer:(const char*)pathName;
- (void)open:(BaseFileMode)fileMode withString:(String*)pathName;

- (BOOL)isOpen;
- (void)close;
- (Size)length;

- (void)seek:(Size)pos;
- (void)seekStart;
- (void)seekEnd;

- (char*)readWithBuffer:(char*)buf;
- (char*)readWithBuffer:(char*)buf size:(int)size;
- (void)readWithString:(String*)str;
- (void)readWithString:(String*)str size:(int)size;

- (int)writeBuffer:(char*)buf;
- (int)writeString:(String*)str;

@end

#endif // BASE_FILE_H