// COPYRIGHT NOTE: Parts of this file are based on the TinyCThread library.
// https://github.com/tinycthread/tinycthread
// They have been altered from the original. The original license follows.
//
// Copyright (c) 2012 Marcus Geelnard
// Copyright (c) 2013-2016 Evan Nemerson
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
//     1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//     2. Altered source versions must be plainly marked as such, and must not
//     be misrepresented as being the original software.
//
//     3. This notice may not be removed or altered from any source
//     distribution.

// TODO: implement TSS?

#include "base/thread.h"
#include "base/array.h"
#include "base/exception.h"
#include "base/selector.h"
#include "internal.h"

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>

#if OS_WINDOWS
#include <windows.h>
#else
#include <errno.h>
#include <pthread.h>
#include <sched.h>
#include <time.h>
#endif // OS_WINDOWS

enum {
	BASE_THREAD_RUNNING,
	BASE_THREAD_FINISHED,
	BASE_THREAD_DETACHED,
};

// Shared between the Thread object and the running thread, so that a detached
// thread does not depend on the Thread object staying alive.
typedef struct {
#if OS_WINDOWS
	HANDLE handle;
#else
	pthread_t handle;
#endif // OS_WINDOWS
	Selector* sel;
	Array* args;
	id result;
	// Thrown by the selector, handed over to `join`.
	id exception;
	atomic_int state;
} BaseThreadContext;

// An exception that `join` did not take over has nobody to catch it.
static void baseThreadContextFree(BaseThreadContext* ctx) {
	if (ctx->exception != nil) {
		baseReportException("Uncaught exception in a detached thread",
							ctx->exception);
		baseReleaseException(ctx->exception);
	}
	[ctx->sel release];
	[ctx->args release];
	free(ctx);
}

static void baseThreadRun(BaseThreadContext* ctx) {
	// `+exit:` is not an exception: it unwinds (if at all) as a forced unwind,
	// which @catch does not stop.
	@try {
		ctx->result = [ctx->sel performWithArgs:ctx->args];
	} @catch (id ex) {
		ctx->exception = ex;
	}
}

// Called when the thread is done, whether it returned or called `+exit:`.
// Whoever comes last (this thread or `detach`) frees the context.
// A joined context is freed by `join`.
static void baseThreadFinish(void* params) {
	BaseThreadContext* ctx = (BaseThreadContext*)params;
	if (atomic_exchange(&ctx->state, BASE_THREAD_FINISHED)
		== BASE_THREAD_DETACHED) {
		baseThreadContextFree(ctx);
	}
}

#if OS_WINDOWS
// Context of the calling thread, when it was started by a Thread.
// ExitThread() does not unwind, so `+exit:` can finish it right away.
static _Thread_local BaseThreadContext* baseCurrentContext = NULL;
#else
// The context is kept in a thread-specific key: its destructor finishes the
// context when the thread ends with pthread_exit(), after the unwinding.
static pthread_key_t baseContextKey;
static BOOL baseContextKeyReady = NO;
static pthread_once_t baseContextKeyOnce = PTHREAD_ONCE_INIT;

static void baseContextKeyCreate(void) {
	baseContextKeyReady =
		pthread_key_create(&baseContextKey, baseThreadFinish) == 0;
}
#endif // OS_WINDOWS

#if OS_WINDOWS
static DWORD WINAPI baseThreadFunction(LPVOID params)
#else
static void* baseThreadFunction(void* params)
#endif // OS_WINDOWS
{
	BaseThreadContext* ctx = (BaseThreadContext*)params;

#if OS_WINDOWS
	baseCurrentContext = ctx;
	baseThreadRun(ctx);
	baseCurrentContext = NULL;
#else
	if (baseContextKeyReady) pthread_setspecific(baseContextKey, ctx);
	baseThreadRun(ctx);
	// returned normally: the destructor must not run
	if (baseContextKeyReady) pthread_setspecific(baseContextKey, NULL);
#endif // OS_WINDOWS

	baseThreadFinish(ctx);
	return 0;
}

@implementation Thread

- (id)init {
	self = [super init];
	if (self) {
		context = nil;
		result = nil;
	}
	return self;
}

- (void)dealloc {
	// dealloc must not throw: report what `join` would have thrown.
	@try {
		[self join];
	} @catch (id ex) {
		baseReportException("Uncaught exception in a released thread", ex);
		baseReleaseException(ex);
		// The thread could not be joined (e.g. it released its own Thread),
		// let it clean up after itself.
		[self detach];
	}
	[super dealloc];
}

- (Array*)args {
	return context ? ((BaseThreadContext*)context)->args : nil;
}

- (Selector*)selector {
	return context ? ((BaseThreadContext*)context)->sel : nil;
}

- (id)result {
	return result;
}

- (void)create:(Selector*)selector {
	Array* args = [Array new];
	@try {
		[self create:selector args:args];
	} @catch (id ex) {
		[args release];
		@throw;
	}
}

- (void)create:(Selector*)selector args:(Array*)arguments {
	if (context)
		@throw [[Exception alloc] initWithFormat:"Failed to create thread. %s",
												 "Thread already created."];

	BaseThreadContext* ctx = calloc(1, sizeof(BaseThreadContext));
	if (ctx == nil)
		@throw [[Exception alloc]
			initWithFormat:"Failed to create thread. %s", "Out of memory."];
	ctx->sel = selector;
	ctx->args = arguments;
	ctx->result = nil;
	ctx->exception = nil;
	atomic_init(&ctx->state, BASE_THREAD_RUNNING);
	result = nil;

#if !OS_WINDOWS
	pthread_once(&baseContextKeyOnce, baseContextKeyCreate);
#endif // !OS_WINDOWS

#if OS_WINDOWS
	ctx->handle = CreateThread(NULL, 0, baseThreadFunction, ctx, 0, NULL);
	const int error = ctx->handle ? 0 : (int)GetLastError();
#else
	const int error =
		pthread_create(&ctx->handle, NULL, baseThreadFunction, ctx);
#endif // OS_WINDOWS

	if (error != 0) {
		// Ownership is only taken on success.
		free(ctx);
		@throw [[Exception alloc]
			initWithFormat:"Failed to create thread. Error code: %i", error];
	}

	context = ctx;
}

- (int)join {
	if (context == nil) return 0;
	BaseThreadContext* ctx = context;

#if OS_WINDOWS
	if (WaitForSingleObject(ctx->handle, INFINITE) == WAIT_FAILED)
		@throw [[Exception alloc]
			initWithFormat:"Failed to join thread [%lu]. %s",
						   GetLastError(),
						   "Unable to wait until it's done."];

	DWORD code = 0;
	if (!GetExitCodeThread(ctx->handle, &code))
		@throw
			[[Exception alloc] initWithFormat:"Failed to join thread [%lu]. %s",
											  GetLastError(),
											  "Unable to get exit code."];

	CloseHandle(ctx->handle);
	const int exitCode = (int)code;
#else
	void* r = NULL;
	const int error = pthread_join(ctx->handle, &r);
	if (error != 0)
		@throw
			[[Exception alloc] initWithFormat:"Failed to join thread [%i]. %s",
											  error,
											  "Can not close thread."];
	const int exitCode = (int)(intptr_t)r;
#endif // OS_WINDOWS

	context = nil;
	result = ctx->result;
	id exception = ctx->exception;
	ctx->exception = nil;
	baseThreadContextFree(ctx);

	if (exception != nil) @throw exception;
	return exitCode;
}

- (BOOL)detach {
	if (context == nil) return NO;
	BaseThreadContext* ctx = context;
	context = nil;

#if OS_WINDOWS
	const BOOL ok = CloseHandle(ctx->handle) != 0;
#else
	const BOOL ok = pthread_detach(ctx->handle) == 0;
#endif // OS_WINDOWS

	if (atomic_exchange(&ctx->state, BASE_THREAD_DETACHED)
		== BASE_THREAD_FINISHED) {
		baseThreadContextFree(ctx);
	}
	return ok;
}

+ (void)exit:(int)code {
#if OS_WINDOWS
	BaseThreadContext* ctx = baseCurrentContext;
	if (ctx != NULL) {
		baseCurrentContext = NULL;
		baseThreadFinish(ctx);
	}
	ExitThread((DWORD)code);
#else
	pthread_exit((void*)(intptr_t)code);
#endif // OS_WINDOWS
}

+ (void)yield {
#if OS_WINDOWS
	Sleep(0);
#else
	sched_yield();
#endif // OS_WINDOWS
}

@end

#if OS_WINDOWS
// A plain mutex is an SRW lock: like a default pthread mutex it can not be
// acquired twice, even by its owner. Critical sections are always recursive.
typedef union {
	SRWLOCK srw;
	CRITICAL_SECTION cs;
} BaseMutex;
#else
typedef pthread_mutex_t BaseMutex;
#endif // OS_WINDOWS

@interface Mutex (BasePrivate)
- (BaseMutex*)nativeMutex;
@end

@implementation Mutex

- (id)init {
	return [self initRecursive:NO];
}

- (id)initRecursive:(BOOL)isRecursive {
	self = [super init];
	if (self) {
		recursive = isRecursive;
		handle = nil;

		BaseMutex* m = calloc(1, sizeof(BaseMutex));
		if (m == nil) {
			[self release];
			baseThrowOutOfMemory("unable to create a mutex!");
		}

#if OS_WINDOWS
		if (recursive) {
			InitializeCriticalSection(&m->cs);
		} else {
			InitializeSRWLock(&m->srw);
		}
		const int error = 0;
#else
		pthread_mutexattr_t attr;
		int error = pthread_mutexattr_init(&attr);
		if (error == 0) {
			if (recursive)
				error =
					pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
			if (error == 0) error = pthread_mutex_init(m, &attr);
			pthread_mutexattr_destroy(&attr);
		}
#endif // OS_WINDOWS

		if (error != 0) {
			free(m);
			[self release];
			@throw [[Exception alloc]
				initWithFormat:"Failed to create mutex. Error code: %i", error];
		}

		handle = m;
	}
	return self;
}

- (void)dealloc {
	BaseMutex* m = handle;
	if (m) {
#if OS_WINDOWS
		// SRW locks need no cleanup
		if (recursive) DeleteCriticalSection(&m->cs);
#else
		pthread_mutex_destroy(m);
#endif // OS_WINDOWS
		free(m);
	}
	[super dealloc];
}

- (BOOL)isRecursive {
	return recursive;
}

- (void)lock {
	BaseMutex* m = handle;
#if OS_WINDOWS
	if (recursive) {
		EnterCriticalSection(&m->cs);
	} else {
		AcquireSRWLockExclusive(&m->srw);
	}
#else
	const int error = pthread_mutex_lock(m);
	if (error != 0)
		@throw [[Exception alloc]
			initWithFormat:"Failed to lock mutex. Error code: %i", error];
#endif // OS_WINDOWS
}

- (BOOL)tryLock {
	BaseMutex* m = handle;
#if OS_WINDOWS
	if (recursive) return TryEnterCriticalSection(&m->cs) ? YES : NO;
	return TryAcquireSRWLockExclusive(&m->srw) ? YES : NO;
#else
	const int error = pthread_mutex_trylock(m);
	if (error == EBUSY) return NO;
	if (error != 0)
		@throw [[Exception alloc]
			initWithFormat:"Failed to lock mutex. Error code: %i", error];
	return YES;
#endif // OS_WINDOWS
}

- (void)unlock {
	BaseMutex* m = handle;
#if OS_WINDOWS
	if (recursive) {
		LeaveCriticalSection(&m->cs);
	} else {
		ReleaseSRWLockExclusive(&m->srw);
	}
#else
	const int error = pthread_mutex_unlock(m);
	if (error != 0)
		@throw [[Exception alloc]
			initWithFormat:"Failed to unlock mutex. Error code: %i", error];
#endif // OS_WINDOWS
}

- (BaseMutex*)nativeMutex {
	return handle;
}

@end

#if OS_WINDOWS
typedef CONDITION_VARIABLE BaseCondition;
#else
typedef pthread_cond_t BaseCondition;
#endif // OS_WINDOWS

// A timeout in seconds, made safe to convert: NaN and negative values are 0,
// anything above ~31 years is "forever".
static double baseTimeout(double seconds) {
	if (!(seconds > 0)) return 0;
	return seconds > 1e9 ? 1e9 : seconds;
}

@implementation Condition

- (id)init {
	self = [super init];
	if (self) {
		handle = nil;

		BaseCondition* c = calloc(1, sizeof(BaseCondition));
		if (c == nil) {
			[self release];
			baseThrowOutOfMemory("unable to create a condition!");
		}

#if OS_WINDOWS
		InitializeConditionVariable(c);
		const int error = 0;
#elif OS_MACOS
		// waits use a relative timeout, see `wait:timeout:`
		const int error = pthread_cond_init(c, NULL);
#else
		// timeouts are measured on the monotonic clock: changing the system
		// time must not shorten or extend them
		pthread_condattr_t attr;
		int error = pthread_condattr_init(&attr);
		if (error == 0) {
			error = pthread_condattr_setclock(&attr, CLOCK_MONOTONIC);
			if (error == 0) error = pthread_cond_init(c, &attr);
			pthread_condattr_destroy(&attr);
		}
#endif // OS_WINDOWS

		if (error != 0) {
			free(c);
			[self release];
			@throw [[Exception alloc]
				initWithFormat:"Failed to create condition. Error code: %i",
							   error];
		}

		handle = c;
	}
	return self;
}

- (void)dealloc {
	BaseCondition* c = handle;
	if (c) {
#if !OS_WINDOWS
		// Windows condition variables need no cleanup
		pthread_cond_destroy(c);
#endif // !OS_WINDOWS
		free(c);
	}
	[super dealloc];
}

- (void)wait:(Mutex*)mutex {
	BaseCondition* c = handle;
	BaseMutex* m = [mutex nativeMutex];
	if (m == NULL)
		@throw [[Exception alloc]
			initWithFormat:"Failed to wait on condition. %s", "No mutex."];

#if OS_WINDOWS
	const BOOL ok = [mutex isRecursive]
						? SleepConditionVariableCS(c, &m->cs, INFINITE)
						: SleepConditionVariableSRW(c, &m->srw, INFINITE, 0);
	if (!ok)
		@throw [[Exception alloc]
			initWithFormat:"Failed to wait on condition. Error code: %lu",
						   GetLastError()];
#else
	const int error = pthread_cond_wait(c, m);
	if (error != 0)
		@throw [[Exception alloc]
			initWithFormat:"Failed to wait on condition. Error code: %i",
						   error];
#endif // OS_WINDOWS
}

- (BOOL)wait:(Mutex*)mutex timeout:(double)seconds {
	BaseCondition* c = handle;
	BaseMutex* m = [mutex nativeMutex];
	if (m == NULL)
		@throw [[Exception alloc]
			initWithFormat:"Failed to wait on condition. %s", "No mutex."];
	seconds = baseTimeout(seconds);

#if OS_WINDOWS
	// INFINITE is 0xFFFFFFFF, stay below it
	// rounded up, so that a short wait does not become 0
	const double ms = seconds * 1000.0;
	DWORD timeout = ms >= 4294967294.0 ? 4294967294u : (DWORD)ms;
	if (timeout < ms && timeout < 4294967294u) timeout++;
	const BOOL ok = [mutex isRecursive]
						? SleepConditionVariableCS(c, &m->cs, timeout)
						: SleepConditionVariableSRW(c, &m->srw, timeout, 0);
	if (ok) return YES;
	const DWORD error = GetLastError();
	if (error == ERROR_TIMEOUT) return NO;
	@throw [[Exception alloc]
		initWithFormat:"Failed to wait on condition. Error code: %lu", error];
#else
	const double whole = (double)(long long)seconds; // >= 0, truncation floors
	struct timespec ts;
#if OS_MACOS
	ts.tv_sec = (time_t)whole;
	ts.tv_nsec = (long)((seconds - whole) * 1e9);
	const int error = pthread_cond_timedwait_relative_np(c, m, &ts);
#else
	clock_gettime(CLOCK_MONOTONIC, &ts);
	ts.tv_sec += (time_t)whole;
	ts.tv_nsec += (long)((seconds - whole) * 1e9);
	if (ts.tv_nsec >= 1000000000L) {
		ts.tv_sec++;
		ts.tv_nsec -= 1000000000L;
	}
	const int error = pthread_cond_timedwait(c, m, &ts);
#endif // OS_MACOS
	if (error == 0) return YES;
	if (error == ETIMEDOUT) return NO;
	@throw [[Exception alloc]
		initWithFormat:"Failed to wait on condition. Error code: %i", error];
#endif // OS_WINDOWS
}

- (void)signal {
#if OS_WINDOWS
	WakeConditionVariable((BaseCondition*)handle);
#else
	pthread_cond_signal((BaseCondition*)handle);
#endif // OS_WINDOWS
}

- (void)broadcast {
#if OS_WINDOWS
	WakeAllConditionVariable((BaseCondition*)handle);
#else
	pthread_cond_broadcast((BaseCondition*)handle);
#endif // OS_WINDOWS
}

@end
