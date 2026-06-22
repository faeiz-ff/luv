const std = @import("std");

const luv = @import("root.zig");

pub const InterpretError = error{
    CompileErr,
    RuntimeErr,
};

const debug_trace_execution = false;

pub const VM = struct {
    const Self = @This();
    chunk: *luv.Chunk,
    ip: usize,
    stack: std.ArrayList(luv.Value),
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer) VM {
        return .{
            .chunk = undefined,
            .ip = undefined,
            .stack = .empty,
            .writer = writer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.resetStack();
    }

    pub fn resetStack(self: *Self) void {
        self.stack.clearAndFree(self.allocator);
    }

    pub fn interpret(self: *Self, chunk: *luv.Chunk) InterpretError!void {
        self.chunk = chunk;
        self.ip = 0;
        return self.run() catch |err| switch (err) {
            error.RuntimeErr => error.RuntimeErr,
            else => error.CompileErr,
        };
    }

    fn readByte(self: *Self) u8 {
        self.ip += 1;
        return self.chunk.bytes.items[self.ip - 1];
    }

    fn readConstant(self: *Self) luv.Value {
        return self.chunk.constants.items[self.readByte()];
    }

    fn binaryOperation(self: *Self, comptime op: luv.OpCode) !void {
        var a = self.pop() orelse return error.RuntimeErr;
        const b = self.pop() orelse return error.RuntimeErr;

        switch (op) {
            .Add => a.data += b.data,
            .Multiply => a.data *= b.data,
            .Divide => {
                if (b.data == 0) return error.RuntimeErr;
                a.data /= b.data;
            },
            else => @compileError(@tagName(op) ++ " OpCode is not a valid binary operator"),
        }

        try self.push(a);
    }

    fn debugInstruction(self: *Self) !void {
        try self.writer.print("STACK:    ", .{});
        for (self.stack.items) |value| {
            try self.writer.print("[ ", .{});
            try value.print(self.writer);
            try self.writer.print(" ]", .{});
        }
        try self.writer.print("\n", .{});
        _ = try luv.debug.dissasembleInstruction(self.chunk, self.writer, self.ip);
    }

    pub fn run(self: *Self) !void {
        while (self.ip < self.chunk.bytes.items.len) {
            if (debug_trace_execution) try self.debugInstruction();

            const instruction: luv.OpCode = @enumFromInt(self.readByte());
            switch (instruction) {
                .Return => return,
                .Constant => {
                    const constant = self.readConstant();
                    try self.push(constant);
                    try constant.print(self.writer);
                    try self.writer.print("\n", .{});
                },
                .ConstantLong => {
                    const b2 = self.readByte();
                    const b1 = self.readByte();
                    const b0 = self.readByte();
                    const index = luv.Chunk.assembleConstantLongIndex(b2, b0, b1);
                    const constant = self.chunk.constants.items[index];
                    try self.push(constant);
                    try constant.print(self.writer);
                    try self.writer.print("\n", .{});
                },
                .Negate => {
                    if (self.stack.items.len == 0) return error.RuntimeErr;
                    self.stack.items[self.stack.items.len - 1].data *= -1;
                },
                .Add => try self.binaryOperation(.Add),
                .Multiply => try self.binaryOperation(.Multiply),
                .Divide => try self.binaryOperation(.Divide),
                else => return error.CompileErr,
            }
        }
    }

    pub fn push(self: *Self, value: luv.Value) !void {
        try self.stack.append(self.allocator, value);
    }

    pub fn pop(self: *Self) ?luv.Value {
        return self.stack.pop();
    }
};

test "Exec instruction" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: std.Io.Writer.Allocating = .init(allocator);
    defer buffer.deinit();
    const writer = &buffer.writer;

    var chunk: luv.Chunk = .init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .data = 67 }, 1);
    try chunk.writeConstant(.{ .data = 67 }, 1);
    try chunk.writeOpCode(.Negate, 1);
    try chunk.writeConstant(.{ .data = 67 }, 1);
    try chunk.writeOpCode(.Multiply, 1);
    try chunk.writeOpCode(.Negate, 1);
    try chunk.writeOpCode(.Divide, 1);
    try chunk.writeOpCode(.Return, 1);

    var vm: VM = .init(allocator, writer);
    defer vm.deinit();
    try vm.interpret(&chunk);

    try t.expectEqualStrings(
        \\67
        \\67
        \\67
        \\
    , buffer.written());

    try t.expectEqual(1, vm.stack.items.len);
}
