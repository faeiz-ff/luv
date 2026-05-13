#include "vm.h"
#include "chunk.h"
#include "debug.h"
#include "value.h"
#include <stdint.h>
#include <stdio.h>

void luv_vm_init(LuvVM *vm)
{
    vm->chunk = NULL;
    vm->ip = NULL;
    luv_da_init(&vm->stack);
}

void luv_vm_deinit(LuvVM *vm)
{
    luv_da_deinit(&vm->stack);
    luv_vm_init(vm);
}

LuvInterpretResult run(LuvVM *vm)
{
#define READ_BYTE() (*vm->ip++)
#define READ_CONSTANT() (vm->chunk->constants.items[READ_BYTE()])
#define BINARY_OP(op)                      \
    do {                                   \
        LuvValue a = luv_vm_stack_pop(vm); \
        LuvValue b = luv_vm_stack_pop(vm); \
        luv_vm_stack_push(vm, a op b);     \
    } while (0)

    for (;;) {
#ifdef LUV_VM_DEBUG_TRACE_EXECUTION
        printf("          ");
        for (size_t i = 0; i < vm->stack.count; i++) {
            printf("[ ");
            luv_value_print(vm->stack.items[i]);
            printf(" ]");
        }
        printf("\n");
        luv_chunk_dissasemble_instruction(vm->chunk, vm->ip - vm->chunk->items);
#endif
        uint8_t instruction = { 0 };
        switch (instruction = READ_BYTE()) {
        case LUV_OP_RETURN: {
            return LUV_INTERPRET_OK;
        }
        case LUV_OP_CONSTANT: {
            luv_vm_stack_push(vm, READ_CONSTANT());
            break;
        }
        case LUV_OP_CONSTANT_LONG: {
            size_t constant_index = READ_BYTE();
            constant_index <<= 8;
            constant_index |= READ_BYTE();
            constant_index <<= 8;
            constant_index |= READ_BYTE();
            luv_vm_stack_push(vm, vm->chunk->constants.items[constant_index]);
            break;
        }
        case LUV_OP_NEGATE: vm->stack.items[vm->stack.count-1] *= -1; break;
        case LUV_OP_ADD: BINARY_OP(+); break;
        case LUV_OP_MULTIPLY: BINARY_OP(*); break;
        case LUV_OP_DIVIDE: BINARY_OP(/); break;
        }
    }
#undef READ_BYTE
#undef READ_CONSTANT
}

LuvInterpretResult luv_vm_interpret(LuvVM *vm, LuvChunk *chunk)
{
    vm->chunk = chunk;
    vm->ip = vm->chunk->items;
    return run(vm);
}

LuvValue luv_vm_stack_pop(LuvVM *vm)
{
    if (vm->stack.count == 0) exit(1);
    return vm->stack.items[--vm->stack.count];
}

void luv_vm_stack_push(LuvVM *vm, LuvValue value)
{
    luv_da_append(LuvValue, &vm->stack, value);
}
