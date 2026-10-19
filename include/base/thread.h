#pragma once

#ifndef BASE_THREAD_H
#define BASE_THREAD_H

#include "base.h"

#include <stdatomic.h>

#define BaseAtomic _Atomic

@class Selector;
@class Array;

// Runs a Selector on a new thread, passing it the `args` array.
//
// Ownership: a successful `create:` takes over the selector and the arguments
// and releases them once the thread has been joined (or has finished, if
// detached). If `create:` throws, they still belong to the caller.
// An unjoined, undetached thread is joined when the Thread is destroyed.
//
// Exceptions: an exception thrown by the selector is rethrown by `join` (and
// then belongs to the caller, like any caught exception). If nobody joins the
// thread (it was detached, or the Thread was released), the exception is
// printed to stderr and released; the process keeps running.
@interface Thread : BaseObject {
	void* context;
	id result;
}

- (id)init;
- (void)dealloc;

// Valid between `create:` and `join`/`detach`, nil otherwise.
- (Array*)args;
- (Selector*)selector;

// Object returned by the selector, available after `join`.
// It is not owned by the Thread.
- (id)result;

- (void)create:(Selector*)selector;
- (void)create:(Selector*)selector args:(Array*)arguments;

// Waits for the thread and returns its exit code: 0 when the selector
// returned normally, or the value passed to `+exit:`. Rethrows the exception
// thrown by the selector, if any; the thread is joined all the same.
- (int)join;
// Lets the thread run on its own. Returns NO if it was not running.
- (BOOL)detach;

// These act on the *calling* thread.
// Note: a detached thread that calls `exit:` leaks its selector and arguments.
+ (void)exit:(int)code __attribute__((noreturn));
+ (void)yield;

// - (BOOL)equal:(Thread*)thread;
// + (BOOL)equal:(Thread*)a and:(Thread*)b;

@end

// Mutual exclusion lock.
//
// A plain mutex must be unlocked by the thread that locked it, and locking it
// again from that thread deadlocks. A recursive one may be locked several
// times by the same thread and must then be unlocked as many times.
// Destroying a locked mutex is undefined.
@interface Mutex : BaseObject {
	void* handle;
	BOOL recursive;
}

- (id)init;
- (id)initRecursive:(BOOL)isRecursive;
- (void)dealloc;

- (BOOL)isRecursive;

- (void)lock;
// Returns NO, without waiting, if another thread holds the lock
// (or the calling thread does, for a plain mutex).
- (BOOL)tryLock;
- (void)unlock;

@end

#endif // BASE_THREAD_H
