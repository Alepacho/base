#pragma once
#ifndef BASE_SYSTEM_H
#define BASE_SYSTEM_H

#include "base.h"

@interface System : BaseObject

+ (void)debug:(const char*)fmt, ...;
+ (void)trace:(const char*)fmt, ...;
+ (void)error:(const char*)fmt, ...;
+ (void)fatal:(const char*)fmt, ...;

+ (void)echo:(const char*)msg;
+ (void)print:(const char*)fmt, ...;
+ (void)println:(const char*)fmt, ...;
+ (char)input;
+ (char*)input:(char*)buffer withLength:(size_t)length;
@end

#endif // BASE_SYSTEM_H
