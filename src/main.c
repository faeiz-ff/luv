#include "vm/chunk.h"
#include "vm/vm.h"
#include <stddef.h>

int main()
{
    Luv_VM vm = {0};
    luv_vm_init(&vm);

    Luv_Chunk chunk;
    luv_chunk_init(&chunk);

    size_t constant = luv_chunk_add_constant(&chunk, 6.7);
    luv_chunk_write(&chunk, LUV_OP_CONSTANT, 1);
    luv_chunk_write(&chunk, constant, 1);

    luv_chunk_write(&chunk, LUV_OP_RETURN, 3);

    luv_vm_interpret(&vm, &chunk);

    luv_chunk_deinit(&chunk);
    luv_vm_deinit(&vm);
}
