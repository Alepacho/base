#pragma once
#ifndef BASE_STRING_H
#define BASE_STRING_H

#include "base.h"

@interface String : BaseObject {
	char* buffer;
}
- (id)init;
- (id)initWithBuffer:(const char*)buf;
- (id)initWithString:(String*)str;
- (id)initWithFormat:(const char*)fmt, ...;

- (void)dealloc;

- (void)clear;
- (char*)buffer;

- (id)appendBuffer:(const char*)buf;
- (id)appendFormat:(const char*)fmt, ...;
- (id)appendChar:(const char)ch;

- (id)setBuffer:(const char*)buf;
- (id)setFormat:(const char*)fmt, ...;
- (id)setString:(String*)str;

- (size_t)length;

- (BOOL)compareBuffer:(const char*)buf;
@end

#endif // BASE_STRING_H
