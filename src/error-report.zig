const std = @import("std");
const builtin = @import("builtin");

pub const ErrorReport = struct {
    count: usize,
    capture: ?std.ArrayListUnmanaged(u8), // For testing

    pub const empty = ErrorReport{
        .count = 0,
        .capture = null,
    };

    pub fn report(
        self: *ErrorReport,
        comptime errheader: []const u8,
        comptime errmsg: ?[]const u8,
        x_pos: usize,
        y_pos: usize,
        code: []const u8,
    ) void {
        self.count += 1;
        self.print("error ({d}:{d}): {s}:\n", .{ y_pos + 1, x_pos, errheader });

        const line = getLine(y_pos, code);
        std.debug.assert(line != null);

        self.print("\t{s}\n", .{line.?});
        if (errmsg) |msg| {
            self.print("\t", .{});
            for (0..x_pos) |_| {
                self.print(" ", .{});
            }

            self.print("^ {s}\n", .{msg});
        }
        self.print("\n", .{});
    }

    fn print(
        self: *ErrorReport,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        if (builtin.is_test) {
            std.debug.assert(self.capture != null);
            self.captured.?.print(std.testing.allocator, fmt, args) catch @panic("Out Of Memory");
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
        } else if (start.? > end.?) {
            return null;
        } else {
            return code[start.?..end.?];
        }
    }
};

test "Getline" {
    const t = std.testing;
    const gl = ErrorReport.getLine;
    const code =
        \\
        \\var x = "Hello world!"
        \\
        \\ 
        // space at the last line
    ;

    try t.expectEqualStrings("", gl(0,code).?);
    try t.expectEqualStrings("var x = \"Hello world!\"", gl(1,code).?);
    try t.expectEqualStrings("", gl(2,code).?);
    try t.expectEqualStrings(" ", gl(3,code).?);
    try t.expect(gl(4,code) == null);

}
