#pragma once
#ifndef ENTITY_H
#define ENTITY_H

#include "base/all.h"

@interface Entity : BaseObject {
	float x, y;
}
- (id)init;
- (id)initX:(float)newX initY:(float)newY;

- (float)x;
- (float)y;
- (void)setX:(float)newX;
- (void)setY:(float)newY;
@end

#endif // ENTITY_H
