#include "base/selector.h"
#include "base/exception.h"

@implementation Selector

- (id)init {
	self = [super init];
	if (self) {
		sel = nil;
		obj = nil;
		res = nil;
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

- (IMP)method {
	return [Selector method:sel object:obj];
}

+ (IMP)method:(SEL)selector object:(id)object {
	return class_getMethodImplementation([object class], selector);
}

- (id)result {
	return res;
}

- (id)perform {
	return res = [Selector perform:sel object:obj];
}

- (id)perform:(SEL)selector {
	return res = [Selector perform:selector object:obj];
}

+ (id)perform:(SEL)selector object:(id)object {
	const IMP msg = [self method:selector object:object];

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];
	return (*msg)(object, selector);
}

+ (id)perform:(SEL)selector object:(id)object args:(Array*)args {
	const IMP msg = [self method:selector object:object];

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

	return (*msg)(object, selector, args);
}

- (id)performWithArgs:(Array*)args {
	return res = [Selector perform:sel object:obj args:args];
}

@end
