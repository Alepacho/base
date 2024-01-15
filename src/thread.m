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
static void* baseThreadFunction(void* params)
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
		data = nil;
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
	if (data)
		@throw [[Exception alloc] initWithFormat:"Failed to create thread. %s",
												 "Thread already created."];
	self->args = arguments;
	self->sel = selector;

#if OS_WINDOWS
	data = CreateThread(NULL, 0, baseThreadFunction, (LPVOID)self, 0, NULL);
#else
	// data = malloc(sizeof(pthread_t));
	pthread_t p = nil;
	if (pthread_create(&p, NULL, baseThreadFunction, (void*)self) != 0) {
		// free(data);
		p = nil;
	}
	data = p;
#endif // OS_WINDOWS

	if (data == nil)
		@throw
			[[Exception alloc] initWithFormat:"Failed to create thread. %i %s",
											  "Thread ID is NULL."];
}

- (int)join {
	if (data == nil) return 0;

#if OS_WINDOWS
	if (WaitForSingleObject(data, INFINITE) == WAIT_FAILED)
		@throw [[Exception alloc]
			initWithFormat:"Failed to join thread. %s",
						   "Unable to wait until it's done."];

	DWORD result;
	BOOL code = GetExitCodeThread(data, &result);
	if (!code)
		@throw
			[[Exception alloc] initWithFormat:"Failed to join thread [%i]. %s",
											  GetLastError(),
											  "Can not close thread."];

	CloseHandle(data);
#else
	void* r;
	if (pthread_join(data, &r) != 0)
		@throw [[Exception alloc] initWithFormat:"Failed to join thread. %s",
												 "Can not close thread."];
	int result = (intptr_t)r;
	// free(data);
#endif // OS_WINDOWS

	data = nil;
	[sel dealloc];
	sel = nil;
	[args dealloc];
	args = nil;

	return result;
}

- (BOOL)detach {
	BOOL result = NO;
#if OS_WINDOWS
	result = CloseHandle(data) != 0;
#else
	result = pthread_detach(data) == 0;
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
