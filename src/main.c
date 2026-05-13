#include "vm/chunk.h"
#include "vm/debug.h"
#include "vm/vm.h"
#include <stddef.h>

int test_vm()
{
#define  WRITE_CONSTANT(n) luv_chunk_write_constant(&chunk, n, 1)
    LuvVM vm = { 0 };
    luv_vm_init(&vm);

    LuvChunk chunk;
    luv_chunk_init(&chunk);


    for (size_t i = 0; i < 256; i++)
        WRITE_CONSTANT(6.7);

    WRITE_CONSTANT(123);


    luv_chunk_write(&chunk, LUV_OP_RETURN, 3);

    // luv_vm_interpret(&vm, &chunk);

    luv_chunk_dissasemble(&chunk, "test chunk");
    luv_chunk_deinit(&chunk);
    luv_vm_deinit(&vm);
    return 0;
#undef WRITE_CONSTANT
}

int main()
{
    test_vm();
}
