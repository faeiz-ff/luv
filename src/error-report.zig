const std = @import("std");

pub const Errors = struct {
    count: usize,
    capture: ?std.ArrayListUnmanaged(u8), // For testing

    pub fn report(
        self: *Errors,
        comptime errheader: []const u8,
        comptime errmsg: ?[]const u8,
        filename: ?[]const u8,
        x_pos: usize,
        y_pos: usize,
        code: []const u8,
    ) void {
        self.count += 1;
        if (filename) |file| {
            self.print(
                "error ({s}:{d}:{d}): {s}:\n",
                .{ file, y_pos + 1, x_pos, errheader },
            );
        } else {
            self.print("error ({d}:{d}): {s}:\n", .{ y_pos + 1, x_pos, errheader });
        }

        const line = Errors.getLine(y_pos, code) orelse return;
        self.print("\t{s}\n\t", .{line});
        for (0..x_pos) |_| {
            self.print(" ", .{});
        }

        if (errmsg) |msg| {
            self.print("^ {s}\n", .{msg});
        }
    }

    fn print(
        self: *Errors,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        if (self.capture) |*captured| {
            captured.print(std.testing.allocator, fmt, args) catch @panic("Out Of Memory");
        } else {
            std.debug.print(fmt, args);
        }
    }

    fn getLine(y_pos: usize, code: []const u8) ?[]const u8 {
        var line_index: usize = 0;
        var start: ?usize = if (y_pos == 0) 0 else null;
        var end: ?usize = null;
        for (code, 0..) |ch, i| {
            if (ch == '\n' and start == null) {
                line_index += 1;
                if (line_index == y_pos) {
                    start = i + 1;
                }
            } else if (ch == '\n' and start != null) {
                end = i;
                break;
            }
        }

        if (start == null) {
            return null;
        } else if (end == null) {
            return code[start.?..];
        } else if (start.? >= end.?) {
            return null;
        } else {
            return code[start.?..end.?];
        }
    }
};

