#include "RLE.h"
#include "memory.h"
#include <stddef.h>

void luv_rle_append(LuvRLE *rle, size_t thing)
{
    if (rle->count == 0) {
        LuvRLEsize_t inserted_data = (LuvRLEsize_t){ .data = thing, .count = 1 };
        luv_da_append(LuvRLEsize_t, rle, inserted_data);
        return;
    }

    LuvRLEsize_t *last_item = &rle->items[rle->count - 1];
    if (last_item->data == thing) {
        last_item->count++;
    } else {
        LuvRLEsize_t inserted_data = (LuvRLEsize_t){ .data = thing, .count = 1 };
        luv_da_append(LuvRLEsize_t, rle, inserted_data);
    }
}

size_t luv_rle_get(LuvRLE *rle, size_t index)
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
