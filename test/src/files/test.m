#include "test.h"

@implementation TestFiles

- (id)init {
	if (self = [super init]) {
	}
	return self;
}
- (void)dealloc {
	[super dealloc];
}

+ (void)execute {
	[System debug:"File test begin"];
	File* file = [File new];

	Exception* exx = nil;
	@try {
		[file open:BASE_FILE_READ withBuffer:"./test.txt"];
	} @catch (Exception* ex) {
		[System warning:"%s\n%s", [ex message], "Test skip."];
		// [ex dealloc];
		exx = ex;
	}

	if (![file isOpen]) {
		[System debug:"Exception is nil: %s", (exx == nil) ? "YES" : "NO"];
		[file dealloc];
		return;
	}
	String* result = [String new];

	[file readWithString:result size:[file length]];

	[System debug:"result: %s", [result buffer]];

	[result dealloc];
	[file dealloc];
	[System debug:"File test end"];
}

@end
