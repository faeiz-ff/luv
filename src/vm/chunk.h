#ifndef LUV_CHUNK_H
#define LUV_CHUNK_H

#include "../utils/RLE.h"
#include "value.h"
#include <stddef.h>
#include <stdint.h>

typedef enum {
    LUV_OP_CONSTANT,
    LUV_OP_CONSTANT_LONG,
    LUV_OP_NEGATE,
    LUV_OP_ADD,
    LUV_OP_MULTIPLY,
    LUV_OP_DIVIDE,
    LUV_OP_RETURN,
} LuvOpCode;

typedef struct {
    uint8_t *items;
    size_t count;
    size_t capacity;
    LuvRLE lines;
    LuvValues constants;
} LuvChunk;

void luv_chunk_init(LuvChunk *chunk);
void luv_chunk_deinit(LuvChunk *chunk);
size_t luv_chunk_add_constant(LuvChunk *chunk, LuvValue value);
void luv_chunk_write(LuvChunk *chunk, uint8_t byte, size_t line);
void luv_chunk_write_constant(LuvChunk *chunk, LuvValue value, size_t line);

#endif
