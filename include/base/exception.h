#pragma once
#ifndef BASE_EXCEPTION_H
#define BASE_EXCEPTION_H

#include "base.h"

@class String;

@interface Exception : BaseObject {
	String* message;
}
- (id)init;
- (id)initWithFormat:(const char*)fmt, ...;
- (const char*)message;
@end

#endif // BASE_EXCEPTION_H
