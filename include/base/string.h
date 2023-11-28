#pragma once
#ifndef BASE_STRING_H
#define BASE_STRING_H

#include "base.h"

@interface String : BaseObject {
	char* buffer;
}
- (id)init;
- (id)initWithBuffer:(const char*)buf;
- (id)initWithFormat:(const char*)fmt, ...;
- (void)dealloc;
- (char*)buffer;
- (id)appendBuffer:(const char*)buf;
- (size_t)length;
@end

#endif // BASE_STRING_H
