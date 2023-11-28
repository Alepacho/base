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
- (char*)buffer;
- (id)appendBuffer:(const char*)buf;
- (id)setBuffer:(const char*)buf;
- (id)setString:(String*)str;
- (size_t)length;
@end

#endif // BASE_STRING_H
