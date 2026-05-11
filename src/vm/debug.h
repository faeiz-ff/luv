#ifndef LUV_DEBUG_H
#define LUV_DEBUG_H

#include "chunk.h"
#include <stddef.h>

void luv_chunk_dissasemble(Luv_Chunk *chunk, const char *name);
size_t luv_chunk_dissasemble_instruction(Luv_Chunk *chunk, size_t offset);

#endif
