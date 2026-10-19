#pragma once
#ifndef BASE_EXCEPTION_H
#define BASE_EXCEPTION_H

#include "base.h"

#include <stdarg.h>

@class String;

// Thrown exceptions are owned by whoever catches them:
// call `release` in the @catch block when you are done with it.
//
// Base reports running out of memory with an Exception whose message starts
// with "Out of memory". Initializers that throw release the new object.
@interface Exception : BaseObject {
	String* message;
}
- (id)init;
- (id)initWithFormat:(const char*)fmt, ... BASE_FORMAT(1, 2);
- (id)initWithFormat:(const char*)fmt arguments:(va_list)args BASE_FORMAT(1, 0);
- (id)initWithString:(String*)str;
- (void)dealloc;
- (const char*)message;

// Optional: makes an uncaught exception print its message (or its class, for
// objects that are not an Exception) to stderr before the process aborts.
// It replaces the process-wide handler, so it is never installed implicitly.
+ (void)installUncaughtHandler;
@end

#endif // BASE_EXCEPTION_H
