#ifndef LUV_VM_H
#define LUV_VM_H

#define LUV_VM_DEBUG_TRACE_EXECUTION

#include "chunk.h"
#include <stdint.h>

typedef struct {
    Luv_Chunk *chunk;
    uint8_t *ip;
} Luv_VM;

typedef enum {
    LUV_INTERPRET_OK,
    LUV_INTERPRET_COMPILER_ERROR,
    LUV_INTERPRET_RUNTIME_ERROR,
} Luv_Interpret_Result;

void luv_vm_init(Luv_VM *vm);
void luv_vm_deinit(Luv_VM *vm);
Luv_Interpret_Result luv_vm_interpret(Luv_VM *vm, Luv_Chunk *chunk);

#endif
