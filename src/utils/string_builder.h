#ifndef LUV_STRING_BUILDER_H
#define LUV_STRING_BUILDER_H

#include "memory.h"
#include <stddef.h>

typedef struct {
    char *items;
    size_t count;
    size_t capacity;
} Luv_String_Builder;

#define luv_sb_deinit luv_da_deinit
#define luv_sb_init luv_da_init

#define luv_sb_append_cstr(sb, text) \
    luv_da_append_many(char, sb, text, strlen(text))

#define luv_sb_append_null(sb) \
    luv_da_append(char, sb, '\0')

#ifdef LUV_NO_PREFIX
#define String_Builder Luv_String_Builder
#define sb_deinit luv_sb_deinit
#define sb_append_cstr luv_sb_append_cstr
#endif

#endif
