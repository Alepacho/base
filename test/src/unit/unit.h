// Shared helpers of the base unit tests.
#pragma once

#include "base/all.h"

#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void unitCheck(BOOL ok, const char* file, int line, const char* text);

// Variadic, so that conditions may contain commas (ObjC messages).
#define CHECK(...)                                                             \
	unitCheck((__VA_ARGS__) ? YES : NO, __FILE__, __LINE__, #__VA_ARGS__)

// Passes when `expr` throws an Exception whose message contains `needle`.
#define CHECK_THROWS_MESSAGE(expr, needle)                                     \
	do {                                                                       \
		BOOL matched = NO;                                                     \
		@try {                                                                 \
			expr;                                                              \
			fprintf(stderr, "%s:%d: nothing thrown\n", __FILE__, __LINE__);    \
		} @catch (Exception * ex) {                                            \
			matched = strstr([ex message], needle) != NULL;                    \
			if (!matched)                                                      \
				fprintf(stderr,                                                \
						"%s:%d: unexpected message '%s'\n",                    \
						__FILE__,                                              \
						__LINE__,                                              \
						[ex message]);                                         \
			[ex release];                                                      \
		}                                                                      \
		unitCheck(matched, __FILE__, __LINE__, "throws: " #expr);              \
	} while (0)

#define CHECK_THROWS(...) CHECK_THROWS_MESSAGE((__VA_ARGS__), "")

// Number that counts destroyed instances in `probeDeallocs`.
@interface Probe : Number
@end

extern atomic_int probeDeallocs;
Probe* probe(Size value);

void testBaseObject(void);
void testString(void);
void testException(void);
void testArray(void);
void testFile(void);
void testSelector(void);
void testThread(void);
void testSystem(void);
