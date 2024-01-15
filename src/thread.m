// COPYRIGHT NOTE: I'm using some parts of the tinycthread library.
// https://github.com/tinycthread/tinycthread

// TODO: implement TSS?
// TODO: implement Mutex?

#include "base/thread.h"
#include "base/array.h"
#include "base/exception.h"
#include "base/selector.h"
#include "base/system.h"

#include <stdatomic.h>

#if OS_WINDOWS
#include <windows.h>
#define base_thread HANDLE
#else
#include <pthread.h>
#define base_thread pthread_t
#endif // OS_WINDOWS

#if OS_WINDOWS
static DWORD WINAPI baseThreadFunction(LPVOID params)
#else
static int baseThreadFunction(void* params)
#endif // OS_WINDOWS
{
	Thread* thread = (Thread*)params;
	[[thread selector] performWithArgs:[thread args]];
	return 0;
}

@implementation Thread

- (id)init {
	self = [super init];
	if (self) {
		tid = nil;
		args = nil;
		sel = nil;
	}
	return self;
}

- (void)dealloc {
	[self join];
	[super dealloc];
}

- (Array*)args {
	return args;
}

- (Selector*)selector {
	return sel;
}

- (void)create:(Selector*)selector {
	[self create:selector args:[Array new]];
}

- (void)create:(Selector*)selector args:(Array*)arguments {
	if (tid)
		@throw [[Exception alloc] initWithFormat:"Failed to create thread. %s",
												 "Thread already created."];
	self->args = arguments;
	self->sel = selector;

#if OS_WINDOWS
	tid = CreateThread(NULL, 0, baseThreadFunction, (LPVOID)self, 0, NULL);
#else
	if (pthread_create(tid, NULL, baseThreadFunction, (void*)self) != 0)
		tid = NULL;
#endif // OS_WINDOWS

	if (tid == NULL)
		@throw
			[[Exception alloc] initWithFormat:"Failed to create thread. %i %s",
											  "Thread ID is NULL."];
}

- (int)join {
	if (tid == nil) return 0;

#if OS_WINDOWS
	if (WaitForSingleObject(tid, INFINITE) == WAIT_FAILED)
		@throw [[Exception alloc]
			initWithFormat:"Failed to join thread. %s",
						   "Unable to wait until it's done."];

	DWORD result;
	BOOL code = GetExitCodeThread(tid, &result);
	if (!code)
		@throw
			[[Exception alloc] initWithFormat:"Failed to join thread [%i]. %s",
											  GetLastError(),
											  "Can not close thread."];

	CloseHandle(tid);
#else
	void* r;
	if (pthread_join(tid, &r) != 0)
		@throw [[Exception alloc] initWithFormat:"Failed to join thread. %s",
												 "Can not close thread."];
	int result = (intptr_t)r;
#endif // OS_WINDOWS

	tid = nil;
	[sel dealloc];
	sel = nil;
	[args dealloc];
	args = nil;

	return result;
}

- (BOOL)detach {
	BOOL result = NO;
#if OS_WINDOWS
	result = CloseHandle(tid) != 0;
#else
	result = pthread_detach(tid) == 0;
#endif // OS_WINDOWS
	return result;
}

- (void)exit:(int)result {
#if OS_WINDOWS
	ExitThread((DWORD)result);
#else
	pthread_exit((void*)(intptr_t)result);
#endif // OS_WINDOWS
}

- (void)yield {
#if OS_WINDOWS
	Sleep(0);
#else
	sched_yield();
#endif // OS_WINDOWS
}

@end
