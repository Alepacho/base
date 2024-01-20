#include "base/selector.h"
#include "base/exception.h"

@implementation Selector

- (id)init {
	self = [super init];
	if (self) {
		sel = nil;
		obj = nil;
		res = nil;
		args = nil;
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

- (Array*)arguments {
	return args;
}

- (id)setArguments:(Array*)arguments {
	args = arguments;
	return self;
}

- (id)setObject:(id)object setSelector:(SEL)selector {
	obj = object;
	sel = selector;
	return self;
}

- (id)setObject:(id)object
	 setSelector:(SEL)selector
	setArguments:(Array*)arguments {
	obj = object;
	sel = selector;
	args = arguments;
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
	return res = [Selector perform:sel object:obj arguments:args];
}

- (id)perform:(SEL)selector {
	return res = [Selector perform:selector object:obj arguments:args];
}

+ (id)perform:(SEL)selector object:(id)object {
	const IMP msg = [self method:selector object:object];

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];
#if OS_MACOS
	return [object performSelector:selector];
#else
	return (*msg)(object, selector);
#endif // OS_MACOS
}

+ (id)perform:(SEL)selector object:(id)object arguments:(Array*)arguments {
	const IMP msg = [self method:selector object:object];

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

#if OS_MACOS
	return [object performSelector:selector withObject:arguments];
#else
	return (*msg)(object, selector, arguments);
#endif // OS_MACOS
}

- (id)performWithArgs:(Array*)arguments {
	return res = [Selector perform:sel object:obj arguments:arguments];
}

@end
