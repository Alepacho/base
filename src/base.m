#import "base/base.h"

@implementation BaseObject

#if OS_MACOS

+ (Class)class {
	return [super class];
}

+ (id)alloc {
	return [super alloc];
}

- (void)dealloc {
	[super dealloc];
}

- (id)init {
	return [super init];
}

+ (id)new {
	return [super new];
}

#else

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

+ (id)new {
	return [[self alloc] init];
}

#endif
@end
