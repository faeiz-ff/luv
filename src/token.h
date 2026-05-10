#ifndef LUV_TOKEN_H
#define LUV_TOKEN_H

#include "utils/string_view.h"
#include <stddef.h>

typedef enum {
    LUV_TT_EOF,
    LUV_TT_UNKNOWN,

    LUV_TT_MINUS,
    LUV_TT_PLUS,
    LUV_TT_ASTERISK,
    LUV_TT_SOLIDUS,
    LUV_TT_MODULUS,
    LUV_TT_LBRACE,
    LUV_TT_RBRACE,
    LUV_TT_LPAREN,
    LUV_TT_RPAREN,
    LUV_TT_LSQUARE,
    LUV_TT_RSQUARE,

    LUV_TT_DOT,
    LUV_TT_COMMA,
    LUV_TT_SEMICOLON,

    LUV_TT_LESS,
    LUV_TT_GREATER,
    LUV_TT_EQUAL,
    LUV_TT_BANG,
    LUV_TT_COLON,

    LUV_TT_EQUAL_EQUAL,
    LUV_TT_ARROW,
    LUV_TT_BANG_EQUAL,
    LUV_TT_LESS_EQUAL,
    LUV_TT_GREATER_EQUAL,
    LUV_TT_COLON_COLON,

    LUV_TT_INT_LITERAL,
    LUV_TT_DOUBLE_LITERAL,

    LUV_TT_NEWLINE,
    LUV_TT_IDENTIFIER,
    LUV_TT_TYPE_ID,

    LUV_TT_NOT,
    LUV_TT_AND,

    LUV_TT_YES,
    LUV_TT_NO,

    LUV_TT_DEF,
    LUV_TT_VAR,
    LUV_TT_FUN,
    LUV_TT_CMP,
    LUV_TT_FOR,

    LUV_TT_TYP,
    LUV_TT_INT,
    LUV_TT_DBL,
    LUV_TT_BOL,
    LUV_TT_STR,

    LUV_TT_OR,
} Luv_Token_Type;

typedef struct {
    Luv_String_View lexeme;
    size_t line_number;
    Luv_Token_Type type;
} Luv_Token;

void luv_tok_from(Luv_Token *tok, Luv_Token_Type type, Luv_String_View *sv, size_t line_number);
void luv_print_token_type(Luv_Token_Type type);
void luv_print_token(Luv_Token *tok);
Luv_Token *luv_tok_key_or_id_from(Luv_String_View *sv, size_t line_number);

#endif
