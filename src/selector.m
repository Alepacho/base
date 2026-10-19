#include "base/selector.h"
#include "base/exception.h"

typedef id (*BaseMsg0)(id, SEL);
typedef id (*BaseMsg1)(id, SEL, id);

@implementation Selector

// @private

// Throws when `object` does not implement `selector`.
// class_getMethodImplementation() never returns NULL (it falls back to the
// forwarding IMP), so the check has to be done explicitly.
+ (IMP)checkedMethod:(SEL)selector object:(id)object {
	if (object == nil || selector == nil)
		@throw [[Exception alloc]
			initWithFormat:"Unable to perform selector '%s' on %s",
						   selector ? sel_getName(selector) : "(null)",
						   object ? "object" : "nil object"];

	Class cls = object_getClass(object);
	if (!class_respondsToSelector(cls, selector))
		@throw [[Exception alloc]
			initWithFormat:"%s '%s' does not respond to selector '%s'",
						   class_isMetaClass(cls) ? "Class" : "Instance of",
						   class_getName(cls),
						   sel_getName(selector)];

	return class_getMethodImplementation(cls, selector);
}

// @public

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
	// object_getClass() returns the metaclass for class objects,
	// so class methods are found too.
	return class_getMethodImplementation(object_getClass(object), selector);
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
	const IMP msg = [self checkedMethod:selector object:object];
	return ((BaseMsg0)msg)(object, selector);
}

+ (id)perform:(SEL)selector object:(id)object argument:(id)argument {
	const IMP msg = [self checkedMethod:selector object:object];
	return ((BaseMsg1)msg)(object, selector, argument);
}

- (id)performWithArgs:(Array*)arguments {
	return res = [Selector perform:sel object:obj argument:arguments];
}

@end
