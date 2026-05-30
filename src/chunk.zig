const std = @import("std");
const Allocator = std.mem.Allocator;

const luv = @import("root.zig");

pub const OpCode = enum(u8) {
    Constant,
    ConstantLong,
    Negate,
    Add,
    Multiply,
    Divide,
    Return,
    _,
};

pub const Chunk = struct {
    const Self = @This();
    bytes: std.ArrayList(u8),
    lines: luv.Rle(usize),
    constants: std.ArrayList(luv.Value),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Chunk {
        return .{
            .bytes = .empty,
            .lines = .init(),
            .constants = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bytes.deinit(self.allocator);
        self.lines.deinit(self.allocator);
        self.constants.deinit(self.allocator);
    }

    pub fn writeByte(self: *Self, byte: u8, line: usize) !void {
        try self.bytes.append(self.allocator, byte);
        try self.lines.append(self.allocator, line);
    }

    pub fn writeOpCode(self: *Self, byte: OpCode, line: usize) !void {
        try self.bytes.append(self.allocator, @intFromEnum(byte));
        try self.lines.append(self.allocator, line);
    }

    pub fn addConstant(self: *Self, constant: luv.Value) !usize {
        try self.constants.append(self.allocator, constant);
        return self.constants.items.len - 1;
    }

    pub fn writeConstant(self: *Self, constant: luv.Value, line: usize) !void {
        var index = try self.addConstant(constant);
        if (self.constants.items.len > 255) {
            try self.writeOpCode(.ConstantLong, line);

            // If the total num of constant are more than a byte == 255
            // we increase indexing to 3 bytes == 16,777,216
            const byte0 = index & 0xFF;
            index >>= 8;
            const byte1 = index & 0xFF;
            index >>= 8;
            const byte2 = index & 0xFF;

            try self.writeByte(@truncate(byte2), line);
            try self.writeByte(@truncate(byte1), line);
            try self.writeByte(@truncate(byte0), line);
        } else {
            try self.writeOpCode(.Constant, line);
            try self.writeByte(@truncate(index), line);
        }
    }

    pub inline fn assembleConstantLongIndex(byte0: u8, byte1: u8, byte2: u8) usize {
        var constantIndex: usize = byte2;
        constantIndex <<= 8;
        constantIndex |= byte1;
        constantIndex <<= 8;
        constantIndex |= byte0;
        return constantIndex;
    }
};

test "Simple Instruction" {
    const expect = std.testing.expect;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk: Chunk = .init(allocator);
    defer chunk.deinit();

    try chunk.writeOpCode(.Add, 1);
    try chunk.writeOpCode(.Return, 1);

    try expect(chunk.bytes.items.len == 2);
    try expect(chunk.lines.data.items.len == 1);

    try chunk.writeOpCode(.Add, 2);

    try expect(chunk.bytes.items.len == 3);
    try expect(chunk.lines.data.items.len == 2);
}

test "Write Constant" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk: Chunk = .init(allocator);
    defer chunk.deinit();

    try chunk.writeConstant(.{ .data = 100 }, 1);
    try chunk.writeConstant(.{ .data = 200 }, 1);
    try chunk.writeOpCode(.Add, 1);
    try chunk.writeOpCode(.Return, 1);

    try t.expectEqual(2 + 2 + 1 + 1, chunk.bytes.items.len);
    try t.expectEqual(2, chunk.constants.items.len);
    try t.expectEqual(1, chunk.lines.data.items.len);

    // First Constant
    try t.expectEqual(OpCode.Constant, @as(OpCode, @enumFromInt(chunk.bytes.items[0])));
    try t.expectEqual(0, chunk.bytes.items[1]);

    // Second Constant
    try t.expectEqual(OpCode.Constant, @as(OpCode, @enumFromInt(chunk.bytes.items[2])));
    try t.expectEqual(1, chunk.bytes.items[3]);
}

test "Write Constant Long" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chunk: Chunk = .init(allocator);
    defer chunk.deinit();

    for (0..255) |_| {
        try chunk.writeConstant(.{ .data = 1 }, 1);
    }
    try t.expectEqual(255 * 2, chunk.bytes.items.len); // Constant short

    try chunk.writeConstant(.{ .data = 1 }, 2);
    try t.expectEqual(255 * 2 + 4, chunk.bytes.items.len); // Constant long inserted

    try t.expectEqual(256, chunk.constants.items.len);
    try t.expectEqual(2, chunk.lines.data.items.len);

    try t.expectEqual(255 * 2 + 4, chunk.lines.getAllCount());
    try t.expectEqual(1, try chunk.lines.get(255 * 2 - 1));
    try t.expectEqual(2, try chunk.lines.get(255 * 2));
}
