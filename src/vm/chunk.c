
#include "chunk.h"
#include "../utils/memory.h"
#include "value.h"
#include <stdint.h>

void luv_chunk_init(Luv_Chunk *chunk)
{
    luv_da_init(chunk);
    luv_rle_init(&chunk->lines);
    luv_value_init(&chunk->values);
}

void luv_chunk_deinit(Luv_Chunk *chunk)
{
    luv_value_deinit(&chunk->values);
    luv_rle_deinit(&chunk->lines);
    luv_da_deinit(chunk);
}

size_t luv_chunk_add_constant(Luv_Chunk *chunk, Luv_Value value)
{
    luv_value_append(&chunk->values, value);
    return chunk->values.count - 1;
}

void luv_chunk_write(Luv_Chunk *chunk, uint8_t byte, size_t line)
{
    luv_da_append(uint8_t, chunk, byte);
    luv_rle_append(&chunk->lines, line);
}
