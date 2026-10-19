// Helpers shared by the base sources, not part of the public API.
#pragma once
#ifndef BASE_INTERNAL_H
#define BASE_INTERNAL_H

#include "base/base.h"

// Throws an Exception with "Out of memory: " followed by the formatted text.
// Terminates the process instead if even that Exception can not be created.
void baseThrowOutOfMemory(const char* fmt, ...) BASE_FORMAT(1, 2)
	__attribute__((noreturn));

// Prints "<prefix>: <message>" for an Exception, or the class of any other
// thrown object, to stderr.
void baseReportException(const char* prefix, id exception);

// Releases a thrown object, if it can be released at all.
void baseReleaseException(id exception);

#endif // BASE_INTERNAL_H
