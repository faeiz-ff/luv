#ifndef LUV_LEXER_H
#define LUV_LEXER_H

#include "token.h"
#include "utils/string_view.h"
#include <stddef.h>

typedef struct {
    LuvStringView code;
    struct {
        LuvToken **items;
        size_t count;
        size_t capacity;
    } tokens;
    size_t line_number;
    char *curr;
    int is_at_end;
} LuvLexer;

void luv_lexer_init(LuvLexer *lexer);
int luv_lexer_lex(LuvLexer *lexer, char *str);
void luv_lexer_deinit(LuvLexer *lexer);

#endif
