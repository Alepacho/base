#include "entity.h"

@implementation Entity

- (id)init {
	self = [super init];

	if (self) {
		self->x = 0;
		self->y = 0;
	}

	return self;
}

- (id)initX:(float)newX initY:(float)newY {
	self = [self init];

	self->x = newX;
	self->y = newY;

	return self;
}

- (float)x {
	return self->x;
}

- (float)y {
	return self->y;
}

- (void)setX:(float)newX {
	self->x = newX;
}

- (void)setY:(float)newY {
	self->y = newY;
}

@end
