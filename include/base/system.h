#pragma once
#ifndef BASE_SYSTEM_H
#define BASE_SYSTEM_H

#include "base.h"

// Each message is written at once: messages printed by several threads at the
// same time do not interleave.
@interface System : BaseObject

+ (void)debug:(const char*)fmt, ... BASE_FORMAT(1, 2);
+ (void)trace:(const char*)fmt, ... BASE_FORMAT(1, 2);
+ (void)warning:(const char*)fmt, ... BASE_FORMAT(1, 2);
+ (void)error:(const char*)fmt, ... BASE_FORMAT(1, 2);
// Prints the message and terminates the process.
+ (void)fatal:(const char*)fmt, ... BASE_FORMAT(1, 2)__attribute__((noreturn));

+ (void)echo:(const char*)msg;
+ (void)print:(const char*)fmt, ... BASE_FORMAT(1, 2);
+ (void)println:(const char*)fmt, ... BASE_FORMAT(1, 2);
// Returns the next character or EOF.
+ (int)input;
+ (char*)input:(char*)buffer withLength:(size_t)length;
@end

#endif // BASE_SYSTEM_H
