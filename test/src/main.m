#include "base/all.h"
#include "entity.h"
#include <stdio.h>

@interface Cat : Entity {
	int health;
}
- (id)init;
- (id)initHealth:(int)newHealth initX:(float)newX initY:(float)newY;
- (int)health;
- (void)setHealth:(int)newHealth;
@end

@implementation Cat
- (id)init {
	self = [super init];

	if (self) {
		self->health = 100;
	}

	return self;
}
- (id)initHealth:(int)newHealth initX:(float)newX initY:(float)newY {
	self = [self initX:newX initY:newY];
	self->health = newHealth;
	return self;
}
- (int)health {
	return self->health;
}
- (void)setHealth:(int)newHealth {
	self->health = newHealth;
}
@end

int main(void) {
	if (NO) {
		@throw [[Exception alloc] init];
	}

	[System debug:"%s", "This is a Debug Test!"];
	[System trace:"%s", "This is a Trace Test!"];
	// [System error:"%s\n", "This is an Error Test!"];

	if (NO) {
		[System print:"Enter character: "];
		char ch = [System input];
		[System println:"Your character is: %c", ch];
	}

	if (YES) {
		@try {
			@throw [[Exception alloc] init];
		} @catch (Exception* ex) {
			[System warning:[ex message]];
		}
	}

	// @try {
	// 	[System input:name withLength:64];
	// 	[System println:"Your name is: %s", name];
	// } @catch (Exception* ex) {
	// 	[System error:"%s\n", [ex getMessage]];
	// 	[ex dealloc];
	// 	return 1;
	// }

	if (NO) {
		[System print:"Enter you name: "];
		char name[64];
		if ([System input:name withLength:64] != nil) {
			[System println:"Your name is: %s", name];
		} else
			[System fatal:"I don't know your name!"];
	}

	Array<Entity*>* arr = [[Array alloc] init];
	// Array<Entity*>* arr = [Array alloc];
	// [System debug:"count: %i", [arr count]];

	[arr push:[[Entity alloc] initX:4 initY:2]];
	[arr push:[[Entity alloc] initX:2 initY:4]];
	[System debug:"count: %i", [arr count]];

	if (NO) {
		[arr pop];
		[System debug:"count: %i", [arr count]];
	}

	if (NO) {
		Entity* e = [arr getByIndex:69];
		[System debug:"Entity[%lu]: { .x = %f, .y = %f }", 69, [e x], [e y]];
	}

	for (size_t i = 0; i < [arr count]; i++) {
		Entity* e = [arr getByIndex:i];
		[System debug:"Entity[%lu]: { .x = %f, .y = %f }", i, [e x], [e y]];
	}

	if (YES) {
		Entity* e = [[Entity alloc] initX:6 initY:9];
		[System debug:"Entity   : { .x = %f, .y = %f }", [e x], [e y]];
		[e dealloc];
	}

	if (NO) {
		[System println:"----------------------"];
		[arr push:[[Entity alloc] initX:10 initY:2]];
		[arr push:[[Entity alloc] initX:20 initY:4]];
		[arr push:[[Entity alloc] initX:30 initY:6]];
		[arr push:[[Entity alloc] initX:40 initY:8]];

		[arr insert:[[Entity alloc] initX:0 initY:25] byIndex:4];
		[arr insert:[[Entity alloc] initX:25 initY:0]];

		for (size_t i = 0; i < [arr count]; i++) {
			Entity* e = [arr getByIndex:i];
			[System debug:"Entity[%lu]: { .x = %f, .y = %f }", i, [e x], [e y]];
		}

		[System println:"Real size of array is: %i", [arr size]];

		[System println:"----------------------"];
		[arr remove];
		[arr remove:4];

		for (size_t i = 0; i < [arr count]; i++) {
			Entity* e = [arr getByIndex:i];
			[System debug:"Entity[%lu]: { .x = %f, .y = %f }", i, [e x], [e y]];
		}

		[System println:"Real size of array is: %i", [arr size]];
	}

	// retain/release test
	if (YES) {
		Cat* cat = [[Cat alloc] initHealth:150 initX:13 initY:37];
		[arr push:cat];
		[cat setX:55];

		[arr remove:1];
		[arr pop];
		[cat setX:88];
		for (size_t i = 0; i < [arr count]; i++) {
			Entity* e = [arr getByIndex:i];
			[System debug:"Entity[%lu]: { .x = %f, .y = %f }", i, [e x], [e y]];
		}

		[System debug:"Cat's health: %i", [cat health]];
	}

	return 0;
}
