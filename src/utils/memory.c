#include "memory.h"
#include <stdlib.h>

void *luv_reallocate(void *ptr, size_t newSize)
{
    if (newSize == 0) {
        free(ptr);
        return NULL;
    }

    ptr = realloc(ptr, newSize);
    if (ptr == NULL) exit(1);
    return ptr;
}
