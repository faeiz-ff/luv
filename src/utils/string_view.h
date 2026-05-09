#ifndef LUV_STRING_VIEW_H
#define LUV_STRING_VIEW_H

#include <stddef.h>
#include <string.h>

typedef struct {
  char *str;
  size_t count;
} Luv_String_View;

void luv_sv_init(Luv_String_View *sv);

#define luv_sv_from(sv, str, count) \
    luv_sv_slice_cstr(sv, str, 0, count)

#define luv_sv_from_cstr(sv, str) \
    luv_sv_slice_cstr(sv, str, 0, strlen(str))

#define luv_sv_from_sv(sv, other) \
    luv_sv_slice_sv(sv, other, 0, (other)->count)

void luv_sv_slice_cstr(Luv_String_View *sv, char *str, size_t start, size_t count);
void luv_sv_slice_sv(Luv_String_View *sv, Luv_String_View *other, size_t start, size_t count);
char *luv_sv_malloc_char(Luv_String_View *sv);
void luv_sv_print(Luv_String_View *sv);

#ifdef LUV_NO_PREFIX
#define String_View Luv_String_View
#define sv_init luv_sv_init
#define sv_from luv_sv_from
#define sv_from_cstr luv_sv_from_cstr
#define sv_slice_cstr luv_sv_slice_cstr
#define sv_slice_sv luv_sv_slice_sv
#define sv_malloc_char luv_sv_malloc_char
#define sv_print luv_sv_print
#endif

#endif 
