#include "base/selector.h"
#include "base/exception.h"

@implementation Selector

- (id)init {
	self = [super init];
	if (self) {
		sel = nil;
		obj = nil;
	}
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (id)object {
	return obj;
}

- (id)setObject:(id)newObject {
	obj = newObject;
	return self;
}

- (SEL)selector {
	return sel;
}

- (id)setSelector:(SEL)newSelector {
	sel = newSelector;
	return self;
}

- (id)perform {
	return [Selector perform:sel object:obj];
}

- (id)perform:(SEL)selector {
	return [Selector perform:selector object:obj];
}

+ (id)perform:(SEL)selector object:(id)object {
	const IMP msg = objc_msg_lookup(object, selector);

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

	return (*msg)(object, selector);
}

@end
