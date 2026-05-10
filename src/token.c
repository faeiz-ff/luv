
#include "token.h"
#include "utils/memory.h"
#include "utils/string_view.h"
#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

void luv_tok_init(Luv_Token *tok)
{
    tok->type = LUV_TT_EOF;
    tok->line_number = 0;
    luv_sv_init(&tok->lexeme);
}

void luv_tok_from(Luv_Token *tok, Luv_Token_Type type, Luv_String_View *sv, size_t line_number)
{
    tok->type = type;
    tok->line_number = line_number;
    luv_sv_init(&tok->lexeme);
    luv_sv_from_sv(&tok->lexeme, sv);
}

Luv_Token *luv_tok_key_or_id_from(Luv_String_View *sv, size_t line_number)
{
    Luv_Token *tok = { 0 };
    tok = luv_realloc(Luv_Token, tok, 1);
    Luv_Token_Type type = LUV_TT_IDENTIFIER;

    if (isupper(*sv->str)) {
        type = LUV_TT_TYPE_ID;
        goto skip_check;
    }

    switch (sv->count) {
    case 2:
        switch (*sv->str) {
        case 'n': strncmp(sv->str, "no", 2) == 0 && (type = LUV_TT_NO); break;
        case 'o': strncmp(sv->str, "or", 2) == 0 && (type = LUV_TT_OR); break;
        }
        break;
    case 3:
        switch (*sv->str) {
        case 'a': strncmp(sv->str, "and", 3) == 0 && (type = LUV_TT_AND); break;
        case 'b': strncmp(sv->str, "bol", 3) == 0 && (type = LUV_TT_BOL); break;
        case 'c': strncmp(sv->str, "cmp", 3) == 0 && (type = LUV_TT_CMP); break;
        case 'd':
            if (strncmp(sv->str, "def", 3) == 0 && (type = LUV_TT_DEF))
                break;
            if (strncmp(sv->str, "dbl", 3) == 0 && (type = LUV_TT_DBL))
                break;
            break;
        case 'f':
            if (strncmp(sv->str, "fun", 3) == 0 && (type = LUV_TT_FUN))
                break;
            if (strncmp(sv->str, "for", 3) == 0 && (type = LUV_TT_FOR))
                break;
            break;
        case 'n': strncmp(sv->str, "not", 3) == 0 && (type = LUV_TT_NOT); break;
        case 's': strncmp(sv->str, "str", 3) == 0 && (type = LUV_TT_STR); break;
        case 't': strncmp(sv->str, "typ", 3) == 0 && (type = LUV_TT_TYP); break;
        case 'y': strncmp(sv->str, "yes", 3) == 0 && (type = LUV_TT_YES); break;
        }
        break;
    }
skip_check:

    luv_tok_from(tok, type, sv, line_number);
    return tok;
}
void luv_print_token_type(Luv_Token_Type type)
{
    char *text = NULL;
    switch (type) {
    case LUV_TT_EOF: text = "EOF"; break;

    case LUV_TT_MINUS: text = "MINUS"; break;
    case LUV_TT_PLUS: text = "PLUS"; break;
    case LUV_TT_ASTERISK: text = "ASTERISK"; break;
    case LUV_TT_SOLIDUS: text = "SOLIDUS"; break;
    case LUV_TT_MODULUS: text = "MODULUS"; break;

    case LUV_TT_LBRACE: text = "LBRACE"; break;
    case LUV_TT_RBRACE: text = "RBRACE"; break;
    case LUV_TT_LPAREN: text = "LPAREN"; break;
    case LUV_TT_RPAREN: text = "RPAREN"; break;
    case LUV_TT_LSQUARE: text = "LSQUARE"; break;
    case LUV_TT_RSQUARE: text = "RSQUARE"; break;

    case LUV_TT_DOT: text = "DOT"; break;
    case LUV_TT_COMMA: text = "COMMA"; break;
    case LUV_TT_SEMICOLON: text = "SEMICOLON"; break;

    case LUV_TT_LESS: text = "LESS"; break;
    case LUV_TT_GREATER: text = "GREATER"; break;
    case LUV_TT_EQUAL: text = "EQUAL"; break;
    case LUV_TT_BANG: text = "BANG"; break;
    case LUV_TT_COLON: text = "COLON"; break;

    case LUV_TT_EQUAL_EQUAL: text = "EQUAL_EQUAL"; break;
    case LUV_TT_ARROW: text = "ARROW"; break;
    case LUV_TT_BANG_EQUAL: text = "BANG_EQUAL"; break;
    case LUV_TT_LESS_EQUAL: text = "LESS_EQUAL"; break;
    case LUV_TT_GREATER_EQUAL: text = "GREATER_EQUAL"; break;
    case LUV_TT_COLON_COLON: text = "COLON_COLON"; break;

    case LUV_TT_INT_LITERAL: text = "INT_LITERAL"; break;
    case LUV_TT_DOUBLE_LITERAL: text = "DOUBLE_LITERAL"; break;
    case LUV_TT_NEWLINE: text = "NEWLINE"; break;
    case LUV_TT_IDENTIFIER: text = "IDENTIFIER"; break;
    case LUV_TT_TYPE_ID: text = "TYPE_ID"; break;

    case LUV_TT_NOT: text = "NOT"; break;
    case LUV_TT_AND: text = "AND"; break;

    case LUV_TT_YES: text = "YES"; break;
    case LUV_TT_NO: text = "NO"; break;

    case LUV_TT_DEF: text = "DEF"; break;
    case LUV_TT_VAR: text = "VAR"; break;
    case LUV_TT_FUN: text = "FUN"; break;
    case LUV_TT_CMP: text = "CMP"; break;
    case LUV_TT_FOR: text = "FOR"; break;

    case LUV_TT_TYP: text = "TYP"; break;
    case LUV_TT_INT: text = "INT"; break;
    case LUV_TT_DBL: text = "DBL"; break;
    case LUV_TT_BOL: text = "BOL"; break;
    case LUV_TT_STR: text = "STR"; break;

    case LUV_TT_OR: text = "OR"; break;

    default: text = "Unknown"; break;
    }

    printf("%s", text);
}

void luv_print_token(Luv_Token *tok)
{
    if (tok->type == LUV_TT_NEWLINE) {
        printf("\\n");
    } else {
        luv_sv_print(&tok->lexeme);
    }
    printf(" ");
    luv_print_token_type(tok->type);
    printf(" line: %zu\n", tok->line_number);
}
