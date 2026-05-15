#ifndef LUV_VALUE_H
#define LUV_VALUE_H

#include "./utils/memory.h"
#include <stddef.h>

typedef double LuvValue;

typedef struct {
    LuvValue *items;
    size_t count;
    size_t capacity;
} LuvValues;

void luv_value_print(LuvValue value);

#define luv_value_append(ptr, thing) luv_da_append(LuvValue, ptr, thing)

#endif
