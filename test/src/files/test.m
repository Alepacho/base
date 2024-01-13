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
	[file open:BASE_FILE_READ withBuffer:"./test.txt"];
	String* result = [String new];

	[file readWithString:result size:[file length]];

	[System debug:"result: %s", [result buffer]];

	[result dealloc];
	[file dealloc];
	[System debug:"File test end"];
}

@end
