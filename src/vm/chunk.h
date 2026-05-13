#ifndef LUV_CHUNK_H
#define LUV_CHUNK_H

#include "../utils/RLE.h"
#include "value.h"
#include <stddef.h>
#include <stdint.h>

typedef enum {
    LUV_OP_CONSTANT,
    LUV_OP_CONSTANT_LONG,
    LUV_OP_RETURN,
} Luv_OpCode;

typedef struct {
    uint8_t *items;
    size_t count;
    size_t capacity;
    Luv_RLE lines;
    Luv_Values constants;
} Luv_Chunk;

void luv_chunk_init(Luv_Chunk *chunk);
void luv_chunk_deinit(Luv_Chunk *chunk);
size_t luv_chunk_add_constant(Luv_Chunk *chunk, Luv_Value value);
void luv_chunk_write(Luv_Chunk *chunk, uint8_t byte, size_t line);
void luv_chunk_write_constant(Luv_Chunk *chunk, Luv_Value value, size_t line);

#endif
