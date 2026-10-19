#pragma once
#ifndef BASE_STRING_H
#define BASE_STRING_H

#include "base.h"

#include <stdarg.h>
#include <stddef.h>

@interface String : BaseObject {
	char* buffer;
}
- (id)init;
- (id)initWithBuffer:(const char*)buf;
- (id)initWithString:(String*)str;
- (id)initWithFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)initWithFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);

- (void)dealloc;

- (void)clear;
- (char*)buffer;

// `nil` and empty strings are allowed and leave the string unchanged.
- (id)appendBuffer:(const char*)buf;
- (id)appendFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)appendFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);
- (id)appendChar:(const char)ch;

- (id)setBuffer:(const char*)buf;
- (id)setFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)setFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);
- (id)setString:(String*)str;

- (size_t)length;

// Full equality check, `nil` is never equal.
- (BOOL)compareBuffer:(const char*)buf;
@end

#endif // BASE_STRING_H
