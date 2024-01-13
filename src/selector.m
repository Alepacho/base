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

- (id)setObject:(id)object {
	obj = object;
	return self;
}

- (SEL)selector {
	return sel;
}

- (id)setSelector:(SEL)selector {
	sel = selector;
	return self;
}

- (id)setObject:(id)object setSelector:(SEL)selector {
	obj = object;
	sel = selector;
	return self;
}

- (id)perform {
	return [Selector perform:sel object:obj];
}

- (id)perform:(SEL)selector {
	return [Selector perform:selector object:obj];
}

+ (id)perform:(SEL)selector object:(id)object {
#if OS_MACOS
	const IMP msg = class_getMethodImplementation([object class], selector);

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

	return [object performSelector:selector];
#else
	const IMP msg = objc_msg_lookup(object, selector);

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

	return (*msg)(object, selector);
#endif // OS_MACOS
}

@end
