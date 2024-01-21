#include "base/selector.h"
#include "base/exception.h"

@implementation Selector

- (id)init {
	self = [super init];
	if (self) {
		sel = nil;
		obj = nil;
		res = nil;
		arg = nil;
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

- (id)argument {
	return arg;
}

- (id)setArgument:(id)argument {
	arg = argument;
	return self;
}

- (id)setObject:(id)object setSelector:(SEL)selector {
	obj = object;
	sel = selector;
	return self;
}

- (id)setObject:(id)object setSelector:(SEL)selector setArgument:(id)argument {
	obj = object;
	sel = selector;
	arg = argument;
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
	return res = [Selector perform:sel object:obj argument:arg];
}

- (id)perform:(SEL)selector {
	return res = [Selector perform:selector object:obj argument:arg];
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

+ (id)perform:(SEL)selector object:(id)object argument:(id)argument {
	const IMP msg = [self method:selector object:object];

	if (!msg)
		@throw [[Exception alloc]
			initWithFormat:"Invalid selector passed to %s", sel_getName(_cmd)];

#if OS_MACOS
	return [object performSelector:selector withObject:argument];
#else
	return (*msg)(object, selector, argument);
#endif // OS_MACOS
}

- (id)performWithArgs:(Array*)arguments {
	return res = [Selector perform:sel object:obj argument:arguments];
}

@end
