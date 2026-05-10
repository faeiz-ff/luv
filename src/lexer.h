#ifndef LUV_LEXER_H
#define LUV_LEXER_H

#include "token.h"
#include "utils/string_view.h"
#include <stddef.h>

typedef struct {
    Luv_Token **items;
    size_t count;
    size_t capacity;
} Luv_Tokens;

typedef struct {
    Luv_String_View code;
    Luv_Tokens tokens;
    size_t line_number;
    char *curr;
    int is_at_end;
} Luv_Lexer;

void luv_lexer_init(Luv_Lexer *lexer);
int luv_lexer_lex(Luv_Lexer *lexer, char *str);
void luv_lexer_deinit(Luv_Lexer *lexer);

#endif
