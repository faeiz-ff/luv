#include "vm/chunk.h"
#include "vm/vm.h"
#include <stddef.h>

int test_vm()
{
#define WRITE_CONSTANT(n) luv_chunk_write_constant(&chunk, n, 1)
#define WRITE_OP(op) luv_chunk_write(&chunk, op, 1)
    LuvVM vm = { 0 };
    luv_vm_init(&vm);

    LuvChunk chunk = {0};
    luv_chunk_init(&chunk);

    WRITE_CONSTANT(15);
    WRITE_CONSTANT(10);
    WRITE_OP(LUV_OP_ADD);

    WRITE_CONSTANT(15);
    WRITE_CONSTANT(10);
    WRITE_OP(LUV_OP_MULTIPLY);

    WRITE_OP(LUV_OP_MULTIPLY);
    WRITE_OP(LUV_OP_RETURN);

    luv_vm_interpret(&vm, &chunk);
    // luv_chunk_dissasemble(&chunk, "test chunk");
    luv_chunk_deinit(&chunk);
    luv_vm_deinit(&vm);
    return 0;
#undef WRITE_CONSTANT
#undef  WRITE_OP
}

int main()
{
    test_vm();
}
