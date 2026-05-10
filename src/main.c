#include "lexer.h"
#include "token.h"
#include "utils/string_builder.h"
#include <stdio.h>
int main()
{

    FILE *fptr;
    fptr = fopen("./syntax/main.luv", "r");
    if (fptr == NULL) {
        printf("File main.luv not found");
        return 1;
    }

    char buf[100] = { 0 };

    Luv_String_Builder sb = { 0 };

    while (fgets(buf, 100, fptr)) {
        luv_sb_append_cstr(&sb, buf);
    }

    Luv_Lexer lex = { 0 };
    if (luv_lexer_lex(&lex, sb.items)) return 1;

    for (size_t i = 0; i < lex.tokens.count; i++) {
        luv_print_token(lex.tokens.items[i]);
    }

    luv_lexer_deinit(&lex);

    return 0;
}
