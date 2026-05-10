#include "lexer.h"
#include "token.h"
#include "utils/memory.h"
#include "utils/string_view.h"
#include <stddef.h>
#include <stdio.h>

void luv_lexer_init(Luv_Lexer *lexer)
{
    lexer->code = (Luv_String_View){ 0 };
    lexer->curr = NULL;
    lexer->line_number = 1;
    lexer->is_at_end = 0;
    luv_da_init(&lexer->tokens);
}

int is_ascii_whitespace(char ch)
{
    return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\v' || ch == '\f';
}

int is_ascii_numeric(char ch)
{
    return ch >= '0' && ch <= '9';
}

int is_ascii_letters(char ch)
{
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}

void advance_curr(Luv_Lexer *lexer)
{
    if ((size_t)lexer->curr - (size_t)lexer->code.str >= lexer->code.count - 1) {
        lexer->is_at_end = 1;
        return;
    } else {
        lexer->curr++;
    }
}

char *peek_next(Luv_Lexer *lexer)
{
    if ((size_t)lexer->curr - (size_t)lexer->code.str >= lexer->code.count - 1) {
        return NULL;
    } else {
        return lexer->curr + 1;
    }
}

void skip_whitespace(Luv_Lexer *lexer)
{
    while (!lexer->is_at_end && is_ascii_whitespace(*lexer->curr)) {
        advance_curr(lexer);
    }
}

Luv_Token *number(Luv_Lexer *lexer)
{
    char *start = lexer->curr;
    Luv_Token_Type type = LUV_TT_INT_LITERAL;
    while (!lexer->is_at_end && is_ascii_numeric(*lexer->curr)) {
        advance_curr(lexer);
    }
    if (!lexer->is_at_end && *lexer->curr == '.' && peek_next(lexer) != NULL &&
        is_ascii_numeric(*peek_next(lexer))) {

        type = LUV_TT_DOUBLE_LITERAL;
        advance_curr(lexer);
        while (!lexer->is_at_end && is_ascii_numeric(*lexer->curr)) {
            advance_curr(lexer);
        }
    }

    Luv_String_View lexeme_sv = { 0 };
    luv_sv_init(&lexeme_sv);
    luv_sv_from(&lexeme_sv, start, (size_t)lexer->curr - (size_t)start);

    Luv_Token *tok = { 0 };
    tok = luv_realloc(Luv_Token, tok, 1);
    luv_tok_from(tok, type, &lexeme_sv, lexer->line_number);

    return tok;
}

Luv_Token *identifier(Luv_Lexer *lexer)
{
    char *start = lexer->curr;
    while (!lexer->is_at_end && is_ascii_letters(*lexer->curr)) {
        advance_curr(lexer);
    }

    Luv_String_View lexeme_sv = { 0 };
    luv_sv_init(&lexeme_sv);

    luv_sv_from(&lexeme_sv, start, (size_t)lexer->curr - (size_t)start);

    return luv_tok_key_or_id_from(&lexeme_sv, lexer->line_number);
}

Luv_Token *get_primitive_token(Luv_Lexer *lexer)
{
    Luv_Token_Type tt = LUV_TT_UNKNOWN;

    Luv_String_View lexeme_sv = { 0 };
    luv_sv_init(&lexeme_sv);
    size_t count = 1;

    char *peek = NULL;

    switch (*lexer->curr) {
    case '\0': tt = LUV_TT_EOF; break;
    case '+': tt = LUV_TT_PLUS; break;
    case '-': tt = LUV_TT_MINUS; break;
    case '*': tt = LUV_TT_ASTERISK; break;
    case '/': tt = LUV_TT_SOLIDUS; break;
    case '%': tt = LUV_TT_MODULUS; break;
    case '{': tt = LUV_TT_LBRACE; break;
    case '}': tt = LUV_TT_RBRACE; break;
    case '(': tt = LUV_TT_LPAREN; break;
    case ')': tt = LUV_TT_RPAREN; break;
    case '[': tt = LUV_TT_LSQUARE; break;
    case ']': tt = LUV_TT_RSQUARE; break;

    case '.': tt = LUV_TT_DOT; break;
    case ',': tt = LUV_TT_COMMA; break;
    case ';': tt = LUV_TT_SEMICOLON; break;

    case '=':
        tt = LUV_TT_EQUAL;
        peek = peek_next(lexer);
        if (peek != NULL) {
            count++;
            switch (*peek) {
            case '=': tt = LUV_TT_EQUAL_EQUAL; break;
            case '>': tt = LUV_TT_ARROW; break;

            default: count--; break;
            }
        }
        break;

    case '<':
        tt = LUV_TT_LESS;
        peek = peek_next(lexer);
        if (peek != NULL) {
            count++;
            switch (*peek) {
            case '=': tt = LUV_TT_LESS_EQUAL; break;
            default: count--; break;
            }
        }
        break;

    case '>':
        tt = LUV_TT_GREATER;
        peek = peek_next(lexer);
        if (peek != NULL) {
            count++;
            switch (*peek) {
            case '=': tt = LUV_TT_GREATER_EQUAL; break;
            default: count--; break;
            }
        }
        break;

    case '!':
        tt = LUV_TT_BANG;
        peek = peek_next(lexer);
        if (peek != NULL) {
            count++;
            switch (*peek) {
            case '=': tt = LUV_TT_BANG_EQUAL; break;
            default: count--; break;
            }
        }
        break;

    case ':':
        tt = LUV_TT_COLON;
        peek = peek_next(lexer);
        if (peek != NULL) {
            count++;
            switch (*peek) {
            case ':': tt = LUV_TT_COLON_COLON; break;
            default: count--; break;
            }
        }
        break;

    case '\n':
        tt = LUV_TT_NEWLINE;
        lexer->line_number += 1;
        break;
    }

    if (tt == LUV_TT_UNKNOWN) return NULL;

    luv_sv_slice_sv(&lexeme_sv, &lexer->code,
                    (size_t)lexer->curr - (size_t)lexer->code.str, count);

    for (size_t i = 0; i < count; i++)
        advance_curr(lexer);

    Luv_Token *tok = NULL;
    tok = luv_realloc(Luv_Token, tok, 1);
    luv_tok_from(tok, tt, &lexeme_sv,
                 lexer->line_number + (tt == LUV_TT_NEWLINE ? -1 : 0));

    return tok;
}

int luv_lexer_lex(Luv_Lexer *lexer, char *str)
{
    luv_lexer_init(lexer);
    Luv_String_View sv = { 0 };
    luv_sv_from_cstr(&sv, str);
    lexer->code = sv;
    lexer->curr = sv.str;

    while (!lexer->is_at_end) {
        skip_whitespace(lexer);

        Luv_Token *tok = {0};

        if (is_ascii_letters(*lexer->curr)) {
            tok = identifier(lexer);
        } else if (is_ascii_numeric(*lexer->curr)) {
            tok = number(lexer);
        } else {
            tok = get_primitive_token(lexer);
        }

        if (tok == NULL) {
            printf("[ERROR] Invalid char: %c at line %zu\n", *lexer->curr, lexer->line_number);
            return 1;
        }
        luv_da_append(Luv_Token *, &lexer->tokens, tok);
    }
    return 0;
}

void luv_lexer_deinit(Luv_Lexer *lexer)
{
    for (size_t i = 0; i < lexer->tokens.count; i++) {
        free(lexer->tokens.items[i]); // freeing the token individually
    }

    // freeing the dynamic array to hold the token
    lexer->tokens.items = luv_realloc(Luv_Token *, lexer->tokens.items, 0);
    luv_lexer_init(lexer);
}
