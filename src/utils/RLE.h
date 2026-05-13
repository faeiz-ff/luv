#ifndef LUV_RLE_H
#define LUV_RLE_H

#include <stddef.h>

typedef struct {
    size_t data;
    size_t count;
} LuvRLEsize_t;

typedef struct {
    LuvRLEsize_t *items;
    size_t count;
    size_t capacity;
} LuvRLE;


#define luv_rle_init luv_da_init
#define luv_rle_deinit luv_da_init

void luv_rle_append(LuvRLE *rle, size_t thing);
size_t luv_rle_get(LuvRLE *rle, size_t index);

#endif
