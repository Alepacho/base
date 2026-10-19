#pragma once
#ifndef BASE_EXCEPTION_H
#define BASE_EXCEPTION_H

#include "base.h"

@class String;

// Thrown exceptions are owned by whoever catches them:
// call `release` in the @catch block when you are done with it.
@interface Exception : BaseObject {
	String* message;
}
- (id)init;
- (id)initWithFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)initWithString:(String*)str;
- (void)dealloc;
- (const char*)message;
@end

#endif // BASE_EXCEPTION_H
