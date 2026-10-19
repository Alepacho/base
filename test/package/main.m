// Uses a few classes of an installed base.

#include <base/all.h>

int main(void) {
	@try {
		Dictionary* d = [Dictionary new];
		[d set:[[Number alloc] initValue:42]
			forKey:[[String alloc] initWithBuffer:"answer"]];
		String* description = [d copyDescription];
		[System println:"base %s: %s", BASE_VERSION_STRING, [description buffer]];
		[description release];
		[d release];
	} @catch (Exception* ex) {
		[System error:"%s", [ex message]];
		[ex release];
		return 1;
	}
	return 0;
}
