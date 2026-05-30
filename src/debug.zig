const std = @import("std");
const luv = @import("root.zig");

pub fn dissasembleChunk(chunk: *luv.Chunk, writer: *std.Io.Writer, name: []const u8) !void {
    try writer.print("==== {s} ====\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.bytes.items.len) {
        offset = try dissasembleInstruction(chunk, writer, offset);
    }
}

pub fn dissasembleInstruction(chunk: *luv.Chunk, writer: *std.Io.Writer, offset: usize) !usize {
    try writer.print("{:0>4} ", .{offset});

    const line = try chunk.lines.get(offset);
    const prevLine = try chunk.lines.get(if (offset == 0) 0 else offset - 1);

    if (offset != 0 and line == prevLine) {
        try writer.print("   | ", .{});
    } else {
        try writer.print("{: >4} ", .{line});
    }

    const instruction: luv.OpCode = @enumFromInt(chunk.bytes.items[offset]);
    switch (instruction) {
        .Return => return simpleInstruction(writer, "RETURN", offset),
        .Constant => return constantInstruction(writer, "CONSTANT", chunk, offset),
        .ConstantLong => return constantLongInstruction(writer, "CONSTANT_LONG", chunk, offset),
        .Negate => return simpleInstruction(writer, "NEGATE", offset),
        .Add => return simpleInstruction(writer, "ADD", offset),
        .Multiply => return simpleInstruction(writer, "MULTIPLY", offset),
        .Divide => return simpleInstruction(writer, "DIVIDE", offset),
        else => {
            try writer.print("Unknown OpCode: {}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn simpleInstruction(writer: *std.Io.Writer, name: []const u8, offset: usize) !usize {
    try writer.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(writer: *std.Io.Writer, name: []const u8, chunk: *luv.Chunk, offset: usize) !usize {
    const constantIndex = chunk.bytes.items[offset + 1];
    try writer.print("{s: <16} {: >4} '", .{ name, constantIndex });
    try chunk.constants.items[constantIndex].print(writer);
    try writer.print("'\n", .{});

    return offset + 2;
}

fn constantLongInstruction(writer: *std.Io.Writer, name: []const u8, chunk: *luv.Chunk, offset: usize) !usize {
    const constantIndex: usize = luv.Chunk.assembleConstantLongIndex(chunk.bytes.items[offset + 1], chunk.bytes.items[offset + 2], chunk.bytes.items[offset + 3]);

    try writer.print("{s: >16} {: >4} '", .{ name, constantIndex });
    try chunk.constants.items[constantIndex].print(writer);
    try writer.print("'\n", .{});

    return offset + 4;
}

test "Simple instruction" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var buffer: std.Io.Writer.Allocating = .init(allocator);
    defer buffer.deinit();

    var chunk: luv.Chunk = .init(allocator);
    defer chunk.deinit();

    try chunk.writeOpCode(.Add, 1);
    try chunk.writeOpCode(.Divide, 1);
    try chunk.writeOpCode(.Return, 1);

    try dissasembleChunk(&chunk, &buffer.writer, "Test");

    const printed = buffer.written();

    try t.expectEqualStrings(
        \\==== Test ====
        \\0000    1 ADD
        \\0001    | DIVIDE
        \\0002    | RETURN
        \\
    ,
        printed,
    );
}

test "Constant instruction" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var buffer: std.Io.Writer.Allocating = .init(allocator);
    defer buffer.deinit();

    var chunk: luv.Chunk = .init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .data = 1 }, 1);
    try chunk.writeConstant(.{ .data = 2 }, 1);
    try chunk.writeOpCode(.Divide, 1);

    try dissasembleChunk(&chunk, &buffer.writer, "Test");

    const printed = buffer.written();

    try t.expectEqualStrings(
        \\==== Test ====
        \\0000    1 CONSTANT            0 '1'
        \\0002    | CONSTANT            1 '2'
        \\0004    | DIVIDE
        \\
    ,
        printed,
    );
}
