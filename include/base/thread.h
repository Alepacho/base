#pragma once

#ifndef BASE_THREAD_H
#define BASE_THREAD_H

#include "base.h"

#include <stdatomic.h>

#define BaseAtomic _Atomic

// typedef struct base_thread base_thread;

@class Selector;
@class Array;

@interface Thread : BaseObject {
	void* data;
	Array* args;
	Selector* sel;
}

- (id)init;
- (void)dealloc;

- (Array*)args;
- (Selector*)selector;
// - (void*)data;

- (void)create:(Selector*)selector;
- (void)create:(Selector*)selector args:(Array*)arguments;

- (int)join;
- (BOOL)detach;
- (void)exit:(int)result;
- (void)yield;

// - (BOOL)equal:(Thread*)thread;
// + (BOOL)equal:(Thread*)a and:(Thread*)b;

@end

#endif // BASE_THREAD_H
