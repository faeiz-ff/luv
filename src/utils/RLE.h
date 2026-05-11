#ifndef LUV_RLE_H
#define LUV_RLE_H

#include <stddef.h>

typedef struct {
    size_t data;
    size_t count;
} Luv_RLE_size_t;

typedef struct {
    Luv_RLE_size_t *items;
    size_t count;
    size_t capacity;
} Luv_RLE;


#define luv_rle_init luv_da_init
#define luv_rle_deinit luv_da_init

void luv_rle_append(Luv_RLE *rle, size_t thing);
size_t luv_rle_get(Luv_RLE *rle, size_t index);

#endif
