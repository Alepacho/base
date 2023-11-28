#import "base/base.h"

@implementation BaseObject

+ (Class)class {
	return self;
}

+ (id)alloc {
	return class_createInstance(self, 0);
}

- (void)dealloc {
	object_dispose(self);
}

- (id)init {
	return self;
}

@end
