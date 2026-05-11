#ifndef LUV_TOKEN_H
#define LUV_TOKEN_H

#include "utils/string_view.h"
#include <stddef.h>

typedef enum {
    // Non visible Token
    LUV_TT_EOF, LUV_TT_UNKNOWN, LUV_TT_NEWLINE,

    // Single pass Token 
    LUV_TT_ASTERISK, LUV_TT_SOLIDUS,
    LUV_TT_MODULUS, LUV_TT_AMPERSAND, LUV_TT_PIPE, LUV_TT_LBRACE,
    LUV_TT_RBRACE, LUV_TT_LPAREN, LUV_TT_RPAREN, LUV_TT_LSQUARE,
    LUV_TT_RSQUARE, LUV_TT_DOT, LUV_TT_COMMA, LUV_TT_SEMICOLON,
    LUV_TT_UNDERSCORE,

    // Ambigous Token, needs peek
    LUV_TT_LESS, LUV_TT_GREATER, LUV_TT_EQUAL,
    LUV_TT_BANG, LUV_TT_COLON, LUV_TT_QUESTION_MARK,
    LUV_TT_MINUS, LUV_TT_PLUS, 

    // Double char token
    LUV_TT_QUESTION_DOT, LUV_TT_EQUAL_EQUAL, LUV_TT_ARROW,
    LUV_TT_BANG_EQUAL, LUV_TT_LESS_EQUAL, LUV_TT_LESS_LESS,
    LUV_TT_GREATER_EQUAL, LUV_TT_GREATER_GREATER, LUV_TT_COLON_COLON,
    LUV_TT_MINUS_MINUS, LUV_TT_PLUS_PLUS,

    // Literals
    LUV_TT_INT_LITERAL, LUV_TT_FLOAT_LITERAL, LUV_TT_STRING_LITERAL,

    // Names
    LUV_TT_IDENTIFIER, LUV_TT_TYPE_ID,

    // Keywords
    LUV_TT_DEF, LUV_TT_VAR, LUV_TT_FUN, LUV_TT_CMP,
    LUV_TT_FOR, LUV_TT_SEE, LUV_TT_TYP, LUV_TT_INT,
    LUV_TT_FLT, LUV_TT_BOL, LUV_TT_STR, LUV_TT_YES, 
    LUV_TT_NOT, LUV_TT_AND, LUV_TT_OR, LUV_TT_NO, 
    LUV_TT_NIL, LUV_TT_STRUCT, LUV_TT_ENUM,

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
