#ifndef LUV_MEMORY_H
#define LUV_MEMORY_H

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define LUV_DA_INIT_CAP 8

#define luv_realloc(type, ptr, newSize)                                      \
  ((type *)luv_reallocate(ptr, (newSize) * sizeof(type)))

#define luv_da_inc_cap(type, ptr)                                            \
  do {                                                                         \
    if ((ptr)->items == NULL || (ptr)->capacity == 0) {                        \
      (ptr)->capacity = LUV_DA_INIT_CAP;                                     \
    } else {                                                                   \
      (ptr)->capacity *= 2;                                                    \
    }                                                                          \
    (ptr)->items = luv_realloc(type, (ptr)->items, (ptr)->capacity);         \
  } while (0)

#define luv_da_append(type, ptr, thing)                                      \
  do {                                                                         \
    if ((ptr)->items == NULL || (ptr)->count >= (ptr)->capacity) {             \
      luv_da_inc_cap(type, (ptr));                                           \
    }                                                                          \
    (ptr)->items[(ptr)->count] = (thing);                                      \
    (ptr)->count++;                                                            \
  } while (0)

#define luv_da_append_many(type, ptr, thing, length)                         \
  do {                                                                         \
    while ((ptr)->items == NULL ||                                             \
           (ptr)->count + (length) >= (ptr)->capacity) {                       \
      luv_da_inc_cap(type, (ptr));                                           \
    }                                                                          \
    memcpy((ptr)->items + (ptr)->count, (thing), (length) * sizeof(type));     \
    (ptr)->count += (length);                                                  \
  } while (0)

#define luv_da_init(ptr)                                                     \
  do {                                                                         \
    (ptr)->items = NULL;                                                       \
    (ptr)->count = 0;                                                          \
    (ptr)->capacity = 0;                                                       \
  } while (0)

void *luv_reallocate(void *ptr, size_t newSize);

#ifdef LUV_NO_PREFIX
#define da_inc_cap luv_da_inc_cap
#define da_append luv_da_append
#define da_init luv_da_init
#define da_append_many luv_da_append_many
#define reallocate luv_reallocate
#endif

#endif
