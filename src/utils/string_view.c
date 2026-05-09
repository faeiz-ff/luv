#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "memory.h"
#include "string_view.h"

void luv_sv_init(Luv_String_View *sv)
{
  sv->str = NULL;
  sv->count = 0;
}

void luv_sv_slice_cstr(Luv_String_View *sv, char *str, size_t start, size_t count) 
{
  sv->str = str + start;
  sv->count = count;
}

void luv_sv_slice_sv(Luv_String_View *sv, Luv_String_View *other, size_t start, size_t count) 
{
  sv->str = other->str + start;
  sv->count = count;
}

char *luv_sv_malloc_char(Luv_String_View *sv) 
{
  char *chars = {0};
  chars = luv_realloc(char, chars, sv->count + 1);

  memcpy(chars, sv->str, sv->count * sizeof(char));

  chars[sv->count] = '\0';
  return chars;
}

void luv_sv_print(Luv_String_View *sv) {
    char chars[sv->count + 1];
    memcpy(chars, sv->str, (sv->count+1) * sizeof(char));
    chars[sv->count] = '\0';
    printf("%s", chars);
}
