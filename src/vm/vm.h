#ifndef LUV_VM_H
#define LUV_VM_H

#include "value.h"
#include <stddef.h>
#define LUV_VM_DEBUG_TRACE_EXECUTION

#include "chunk.h"
#include <stdint.h>

typedef struct {
    LuvChunk *chunk;
    uint8_t *ip;
    struct {
        LuvValue *items;
        size_t count;
        size_t capacity;
    } stack;
} LuvVM;

typedef enum {
    LUV_INTERPRET_OK,
    LUV_INTERPRET_COMPILER_ERROR,
    LUV_INTERPRET_RUNTIME_ERROR,
} LuvInterpretResult;

void luv_vm_init(LuvVM *vm);
void luv_vm_deinit(LuvVM *vm);
LuvInterpretResult luv_vm_interpret(LuvVM *vm, LuvChunk *chunk);
LuvValue luv_vm_stack_pop(LuvVM *vm);
void luv_vm_stack_push(LuvVM *vm, LuvValue value);

#endif
