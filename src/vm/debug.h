#ifndef LUV_DEBUG_H
#define LUV_DEBUG_H

#include "chunk.h"
#include <stddef.h>

void luv_chunk_dissasemble(LuvChunk *chunk, const char *name);
size_t luv_chunk_dissasemble_instruction(LuvChunk *chunk, size_t offset);

#endif
