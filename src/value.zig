const std = @import("std");

pub const Value = struct {
    const Self = @This();
    data: f64,

    pub fn print(self: *Self, writer: *std.Io.Writer) !void {
        try writer.print("{}", .{self.data});
    }
};
