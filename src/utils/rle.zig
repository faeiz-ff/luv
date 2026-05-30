const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Rle(comptime T: type) type {
    const RlePair = struct { thing: T, counter: usize };
    return struct {
        const Self = @This();
        data: std.ArrayList(RlePair),

        pub fn init() Self {
            return .{
                .data = .empty,
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.data.deinit(allocator);
        }

        pub fn append(self: *Self, allocator: Allocator, item: T) error{OutOfMemory}!void {
            if (self.data.items.len > 0) {
                const last = &self.data.items[self.data.items.len - 1];
                if (last.thing == item) {
                    last.counter += 1;
                    return;
                }
            }

            try self.data.append(allocator, .{
                .thing = item,
                .counter = 1,
            });
        }

        pub fn get(self: *Self, index: usize) error{OutOfBounds}!T {
            var i = index;
            for (self.data.items) |*it| {
                if (it.counter > i) return it.thing;
                i -= it.counter;
            }

            return error.OutOfBounds;
        }

        pub fn getAllCount(self: *Self) usize {
            var count: usize = 0;
            for (self.data.items) |it| {
                count += it.counter;
            }
            return count;
        }
    };
}

test "Basic Functionality" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rle: Rle(u32) = .init();
    defer rle.deinit(allocator);

    // 123 123 123 124 124 125
    // [123, 3] [124, 2] [125, 1]
    // index 0-2 -> 123
    // index 3-4 -> 124
    // index 5 -> 125

    const inputList = [_]u32{ 1, 1, 1, 2, 2, 3, 3 };

    for (inputList) |i| {
        try rle.append(allocator, i);
    }

    for (0..inputList.len) |i| {
        try t.expectEqual(inputList[i], rle.get(i));
    }

    try t.expectEqual(3, rle.data.items.len);
}

test "Out Of Bound" {
    const t = std.testing;

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rle: Rle(u32) = .init();
    defer rle.deinit(allocator);

    try t.expectError(error.OutOfBounds, rle.get(0));
    try t.expectError(error.OutOfBounds, rle.get(1));
}
