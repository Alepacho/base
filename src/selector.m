#include "base/selector.h"
#include "base/exception.h"

#include <string.h>

typedef id (*BaseMsg0)(id, SEL);
typedef id (*BaseMsg1)(id, SEL, id);
typedef void (*BaseVoidMsg0)(id, SEL);
typedef void (*BaseVoidMsg1)(id, SEL, id);

// Skips the qualifiers (const, in, out, oneway...) of an encoded type.
static char baseTypeKind(const char* type) {
	while (*type != '\0' && strchr("rnNoORVA", *type) != NULL)
		type++;
	return *type;
}

// Objects, blocks and classes are all passed and returned as an `id`.
static BOOL baseIsObjectType(const char* type) {
	const char kind = baseTypeKind(type);
	return kind == '@' || kind == '#';
}

@implementation Selector

// @private

// Calls `selector` on `object`, passing `argument` when the method takes one.
// Methods are called through a function pointer of their exact type, so
// anything but object (or void) results and object arguments is rejected.
+ (id)invoke:(SEL)selector object:(id)object argument:(id)argument {
	if (object == nil || selector == nil)
		@throw [[Exception alloc]
			initWithFormat:"Unable to perform selector '%s' on %s",
						   selector ? sel_getName(selector) : "(null)",
						   object ? "object" : "nil object"];

	// class_getMethodImplementation() never returns NULL (it falls back to
	// the forwarding IMP), so the check has to be done explicitly.
	// object_getClass() returns the metaclass for class objects,
	// so class methods are found too.
	Class cls = object_getClass(object);
	const Method method = class_respondsToSelector(cls, selector)
							  ? class_getInstanceMethod(cls, selector)
							  : NULL;
	if (method == NULL)
		@throw [[Exception alloc]
			initWithFormat:"%s '%s' does not respond to selector '%s'",
						   class_isMetaClass(cls) ? "Class" : "Instance of",
						   class_getName(cls),
						   sel_getName(selector)];

	char type[64];
	method_getReturnType(method, type, sizeof(type));
	const BOOL returnsVoid = baseTypeKind(type) == 'v';
	if (!returnsVoid && !baseIsObjectType(type))
		@throw [[Exception alloc]
			initWithFormat:"Unable to perform selector '%s': it returns '%s', "
						   "not an object",
						   sel_getName(selector),
						   type];

	// self and _cmd come first
	const unsigned count = method_getNumberOfArguments(method);
	if (count == 3) {
		method_getArgumentType(method, 2, type, sizeof(type));
		if (!baseIsObjectType(type))
			@throw [[Exception alloc]
				initWithFormat:"Unable to perform selector '%s': its argument "
							   "is '%s', not an object",
							   sel_getName(selector),
							   type];
	} else if (count != 2) {
		@throw [[Exception alloc]
			initWithFormat:"Unable to perform selector '%s': it takes %u "
						   "arguments, at most 1 is supported",
						   sel_getName(selector),
						   count - 2];
	}

	// Through `void (*)(void)`: IMP is variadic with libobjc2, and casting it
	// straight to another function type is a warning.
	typedef void (*BaseFunction)(void);
	const BaseFunction imp = (BaseFunction)method_getImplementation(method);
	if (returnsVoid) {
		if (count == 2) {
			((BaseVoidMsg0)imp)(object, selector);
		} else {
			((BaseVoidMsg1)imp)(object, selector, argument);
		}
		return nil;
	}
	if (count == 2) return ((BaseMsg0)imp)(object, selector);
	return ((BaseMsg1)imp)(object, selector, argument);
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
	return [self invoke:selector object:object argument:nil];
}

+ (id)perform:(SEL)selector object:(id)object argument:(id)argument {
	return [self invoke:selector object:object argument:argument];
}

- (id)performWithArgs:(Array*)arguments {
	return res = [Selector perform:sel object:obj argument:arguments];
}

@end
