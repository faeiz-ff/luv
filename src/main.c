#include "vm/chunk.h"
#include "vm/debug.h"
#include <stddef.h>

int main()
{
    Luv_Chunk chunk;
    luv_chunk_init(&chunk);
    luv_chunk_write(&chunk, LUV_OP_RETURN, 1);

    size_t constant = luv_chunk_add_constant(&chunk, 6.7);
    luv_chunk_write(&chunk, LUV_OP_CONSTANT, 1);
    luv_chunk_write(&chunk, constant, 1);

    constant = luv_chunk_add_constant(&chunk, 1.2);
    luv_chunk_write(&chunk, LUV_OP_CONSTANT, 2);
    luv_chunk_write(&chunk, constant, 2);

    luv_chunk_write(&chunk, LUV_OP_RETURN, 2);

    luv_chunk_dissasemble(&chunk, "test chunk");
    luv_chunk_deinit(&chunk);
}
