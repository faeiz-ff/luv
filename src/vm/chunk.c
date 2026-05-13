
#include "chunk.h"
#include "../utils/memory.h"
#include "value.h"
#include <stddef.h>
#include <stdint.h>

void luv_chunk_init(LuvChunk *chunk)
{
    luv_da_init(chunk);
    luv_rle_init(&chunk->lines);
    luv_value_init(&chunk->constants);
}

void luv_chunk_deinit(LuvChunk *chunk)
{
    luv_value_deinit(&chunk->constants);
    luv_rle_deinit(&chunk->lines);
    luv_da_deinit(chunk);
}

size_t luv_chunk_add_constant(LuvChunk *chunk, LuvValue value)
{
    luv_value_append(&chunk->constants, value);
    return chunk->constants.count - 1;
}

void luv_chunk_write(LuvChunk *chunk, uint8_t byte, size_t line)
{
    luv_da_append(uint8_t, chunk, byte);
    luv_rle_append(&chunk->lines, line);
}

void luv_chunk_write_constant(LuvChunk *chunk, LuvValue value, size_t line)
{
    size_t index = luv_chunk_add_constant(chunk, value);
    if (chunk->constants.count > 256) {
        luv_chunk_write(chunk, LUV_OP_CONSTANT_LONG, line);

        uint8_t byte0, byte1, byte2;
        byte0 = index & 0xFF;
        index >>= 8;
        byte1 = index & 0xFF;
        index >>= 8;
        byte2 = index & 0xFF;

        luv_chunk_write(chunk, byte2, line);
        luv_chunk_write(chunk, byte1, line);
        luv_chunk_write(chunk, byte0, line);
              
    } else {
        luv_chunk_write(chunk, LUV_OP_CONSTANT, line);
        luv_chunk_write(chunk, index, line);
    }
}

