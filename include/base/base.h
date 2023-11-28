#pragma once
#ifndef BASE_MAIN_H
#define BASE_MAIN_H

// https://github.com/gnustep/libs-base
#include <objc/runtime.h>

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif

#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
@interface BaseObject {
	id isa;
}

+ (id)alloc;
- (void)dealloc;

- (id)init;

@end

#endif // BASE_MAIN_H
