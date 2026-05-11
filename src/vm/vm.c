#include "vm.h"
#include "chunk.h"
#include "debug.h"
#include <stdint.h>
#include <stdio.h>

void luv_vm_init(Luv_VM *vm)
{
    vm->chunk = NULL;
    vm->ip = NULL;
}

void luv_vm_deinit(Luv_VM *vm)
{
    luv_vm_init(vm);
}

Luv_Interpret_Result run(Luv_VM *vm)
{
#define READ_BYTE() (*vm->ip++)
#define READ_CONSTANT() (vm->chunk->constants.items[READ_BYTE()])

    for (;;) {
#ifdef LUV_VM_DEBUG_TRACE_EXECUTION
        luv_chunk_dissasemble_instruction(vm->chunk, vm->ip - vm->chunk->items);
#endif
        uint8_t instruction = { 0 };
        switch (instruction = READ_BYTE()) {
        case LUV_OP_RETURN: {
            return LUV_INTERPRET_OK;
        }
        case LUV_OP_CONSTANT: {
            return LUV_INTERPRET_OK;
        }
        }
    }
#undef READ_BYTE
#undef READ_CONSTANT
}

Luv_Interpret_Result luv_vm_interpret(Luv_VM *vm, Luv_Chunk *chunk)
{
    vm->chunk = chunk;
    vm->ip = vm->chunk->items;
    return run(vm);
}
