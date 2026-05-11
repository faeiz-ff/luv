#ifndef LUV_VALUE_H
#define LUV_VALUE_H

#include "../utils/memory.h"
#include <stddef.h>

typedef double Luv_Value;

typedef struct {
    Luv_Value *items;
    size_t count;
    size_t capacity;
} Luv_Values;

void luv_value_print(Luv_Value value);

#define luv_value_init luv_da_init
#define luv_value_deinit luv_da_deinit
#define luv_value_append(ptr, thing) luv_da_append(Luv_Value, ptr, thing)

#endif
