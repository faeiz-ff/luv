#include <stddef.h>
#include <stdlib.h>

#include "string_builder.h"

void luv_sb_deinit(Luv_String_Builder *sb)
{
    free(sb->items);
    luv_da_init(sb);
}
