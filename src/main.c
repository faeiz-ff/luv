#include "lexer.h"
#include "token.h"
#include "utils/memory.h"
#include "utils/string_builder.h"
#include "chunk.h"
#include "vm.h"
#include <stddef.h>
#include <stdio.h>

int test_vm()
{
#define WRITE_CONSTANT(n) luv_chunk_write_constant(&chunk, n, 1)
#define WRITE_OP(op) luv_chunk_write(&chunk, op, 1)
    LuvVM vm = { 0 };
    luv_vm_init(&vm);

    LuvChunk chunk = { 0 };
    luv_chunk_init(&chunk);

    WRITE_CONSTANT(15);
    WRITE_CONSTANT(10);
    WRITE_OP(LUV_OP_ADD);

    WRITE_CONSTANT(15);
    WRITE_CONSTANT(10);
    WRITE_OP(LUV_OP_ADD);

    WRITE_OP(LUV_OP_MULTIPLY);
    WRITE_OP(LUV_OP_RETURN);

    luv_vm_interpret(&vm, &chunk);
    // luv_chunk_dissasemble(&chunk, "test chunk");
    luv_chunk_deinit(&chunk);
    luv_vm_deinit(&vm);
    return 0;
#undef WRITE_CONSTANT
#undef WRITE_OP
}

int luv_run_file(const char* path)
{
    LuvStringBuilder sb = {0};
    luv_da_init(&sb);

    FILE *fptr = fopen(path, "rb");
    if (fptr == NULL) {
        fprintf(stderr, "[ERROR] file %s not found\n", path);
        exit(74);
    } 

    char buf[256];
    while (fgets(buf, 100, fptr)) {
        luv_sb_append_cstr(&sb, buf);
    }

    luv_sb_append_null(&sb);

    LuvLexer lexer = {0};
    luv_lexer_init(&lexer);

    luv_lexer_lex(&lexer, sb.items);

    for (size_t i = 0; i < lexer.tokens.count; i++) {
        luv_print_token(lexer.tokens.items[i]);
    }

    return 0;
}


int main(int argc, const char *argv[])
{
    if (argc == 2) {
        luv_run_file(argv[1]);
    } else {
        fprintf(stderr, "usage: luv [PATH]\n");
        exit(64);
    }
}
