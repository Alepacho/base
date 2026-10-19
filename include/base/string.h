#pragma once
#ifndef BASE_STRING_H
#define BASE_STRING_H

#include "base.h"

#include <stdarg.h>
#include <stddef.h>

// A growable byte string. The `...length:` methods take raw bytes, which may
// contain NUL characters; the other ones take C strings. The buffer is always
// followed by a NUL, so it can be used as a C string either way.
//
// Running out of memory throws an Exception, the string is then unchanged.
@interface String : BaseObject {
	char* buffer;
	size_t length;
	size_t capacity;
}
- (id)init;
- (id)initWithBuffer:(const char*)buf;
- (id)initWithBuffer:(const char*)buf length:(size_t)len;
- (id)initWithString:(String*)str;
- (id)initWithFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)initWithFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);

- (void)dealloc;

// Empties the string. A big buffer is given back to the system.
- (void)clear;
// Gives back the memory that the current contents do not need.
- (id)shrink;
// The bytes may be changed in place, but not the length: use the methods
// below for that.
- (char*)buffer;

// `nil` and empty strings are allowed and leave the string unchanged.
- (id)appendBuffer:(const char*)buf;
- (id)appendBuffer:(const char*)buf length:(size_t)len;
- (id)appendFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)appendFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);
// Appending '\0' does nothing, use `appendBuffer:length:` for that.
- (id)appendChar:(const char)ch;

- (id)setBuffer:(const char*)buf;
- (id)setBuffer:(const char*)buf length:(size_t)len;
- (id)setFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)setFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);
- (id)setString:(String*)str;

// Number of bytes, NUL characters included.
- (size_t)length;

// Full equality check with a C string, `nil` is never equal.
- (BOOL)compareBuffer:(const char*)buf;

// Strings are equal when they hold the same bytes.
- (BOOL)isEqual:(id)object;
- (BaseSize)hash;
- (id)copy;
- (String*)copyDescription;
@end

#endif // BASE_STRING_H
