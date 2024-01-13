#include <stdio.h>

#include "base/all.h"

#include "basic/test.h"
#include "selectors/test.h"

int main(void) {
	@try {
		// [TestBasic execute];
		[TestSelectors execute];

	} @catch (Exception* ex) {
		[System fatal:"%s", [ex message]];
	}

	return 0;
}
