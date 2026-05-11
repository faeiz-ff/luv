#include "debug.h"
#include "chunk.h"
#include "value.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

static size_t simple_instruction(const char *name, size_t offset)
{
    printf("%s\n", name);
    return offset + 1;
}

static size_t constant_instruction(const char *name, Luv_Chunk *chunk, size_t offset)
{
    size_t constant_index = chunk->items[offset + 1];
    printf("%-16s %4zu '", name, constant_index);
    luv_value_print(chunk->values.items[constant_index]);
    printf("'\n");
    return offset + 2;
}

void luv_chunk_dissasemble(Luv_Chunk *chunk, const char *name)
{
    printf("=== %s ===\n", name);

    for (size_t offset = 0; offset < chunk->count;) {
        offset = luv_chunk_dissasemble_instruction(chunk, offset);
    }
}

size_t luv_chunk_dissasemble_instruction(Luv_Chunk *chunk, size_t offset)
{
    printf("%04zu ", offset);

    size_t line = luv_rle_get(&chunk->lines, offset);
    size_t prev_line = luv_rle_get(&chunk->lines, offset == 0 ? 0 : offset - 1);

    if (offset != 0 && line == prev_line) {
        printf("   | ");
    } else {
        printf("%4zu ", line);
    }

    uint8_t instruction = chunk->items[offset];
    switch (instruction) {
    case LUV_OP_RETURN: return simple_instruction("RETURN", offset);
    case LUV_OP_CONSTANT:
        return constant_instruction("CONSTANT", chunk, offset);
    default: printf("Unknown OpCode: %d\n", instruction); return offset + 1;
    }
}
