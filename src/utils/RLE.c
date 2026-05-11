
#include "RLE.h"
#include "memory.h"
#include <stddef.h>

void luv_rle_append(Luv_RLE *rle, size_t thing)
{
    if (rle->count == 0) {
        Luv_RLE_size_t inserted_data = (Luv_RLE_size_t){ .data = thing, .count = 1 };
        luv_da_append(Luv_RLE_size_t, rle, inserted_data);
        return;
    }

    Luv_RLE_size_t *last_item = &rle->items[rle->count - 1];
    if (last_item->data == thing) {
        last_item->count++;
    } else {
        Luv_RLE_size_t inserted_data = (Luv_RLE_size_t){ .data = thing, .count = 1 };
        luv_da_append(Luv_RLE_size_t, rle, inserted_data);
    }
}

size_t luv_rle_get(Luv_RLE *rle, size_t index)
{
    if (rle->count == 0)
        return 0;

    // 123 123 123 124 124 125
    // [123, 3] [124, 2] [125, 1]
    // index 0-2 -> 123
    // index 3-4 -> 124
    // index 5 -> 125

    size_t actual_index = 0;
    while (index) {
        if (rle->items[actual_index].count > index) {
            index = 0;
        } else {
            index -= rle->items[actual_index].count;
            actual_index++;
        }
    }

    return rle->items[actual_index].data;
}
