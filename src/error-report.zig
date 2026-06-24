const std = @import("std");
const builtin = @import("builtin");

pub const Position = struct {
    x: usize,
    y: usize,
};

/// Ansi Colors add reset to color it back to normal
const Colors = struct {
    const Reset = "\x1b[0m";
    const Black = "\x1b[0;30;49m";
    const BrightBlack = "\x1b[0;90;49m";
    const Red = "\x1b[0;31;49m";
    const BrightRed = "\x1b[0;91;49m";
    const Green = "\x1b[0;32;49m";
    const Yellow = "\x1b[0;33;49m";
    const Blue = "\x1b[0;34;49m";
    const Purple = "\x1b[0;35;49m";
    const Cyan = "\x1b[0;36;49m";
    const White = "\x1b[0;37;49m";
};

// TODO: Make this not global
const Ansi = true;

/// For error reporting on a custom writer
/// Support Ansi Coloring
pub const ErrorReport = struct {
    const Self = @This();
    count: usize,
    hasFailedWrite: bool,
    writer: *std.Io.Writer,

    pub fn init(writer: *std.Io.Writer) Self {
        return .{
            .count = 0,
            .hasFailedWrite = false,
            .writer = writer,
        };
    }

    /// Restore state if previous flush has failed
    pub fn restoreState(self: *Self) void {
        self.hasFailedWrite = false;
    }

    /// Report an Err, increments report counter
    pub fn err(self: *Self, comptime errheader: []const u8) *Self {
        if (self.hasFailedWrite) return self;

        self.count += 1;
        if (Ansi) {
            self.safePrint("{s}[ERR] {s}{s}{s}:\n", .{
                Colors.Red,
                Colors.White,
                errheader,
                Colors.Reset,
            });
        } else {
            self.safePrint("[ERR] {s}:\n", .{errheader});
        }
        return self;
    }

    /// Report a Warn, increments report counter
    pub fn warn(self: *Self, comptime errheader: []const u8) *Self {
        if (self.hasFailedWrite) return self;

        self.count += 1;
        if (Ansi) {
            self.safePrint("{s}[WARN] {s}{s}{s}:\n", .{
                Colors.gyellow,
                Colors.White,
                errheader,
                Colors.Reset,
            });
        } else {
            self.safePrint("[WARN] {s}:\n", .{errheader});
        }
        return self;
    }

    /// Report an Info, increments report counter
    pub fn info(self: *Self, comptime errheader: []const u8) *Self {
        if (self.hasFailedWrite) return self;

        self.count += 1;
        if (Ansi) {
            self.safePrint("{s}[INFO] {s}{s}{s}:\n", .{
                Colors.Cyan,
                Colors.White,
                errheader,
                Colors.Reset,
            });
        } else {
            self.safePrint("[INFO] {s}:\n", .{errheader});
        }
        return self;
    }

    /// Attach a file name with a position marker to the report
    pub fn withFileName(self: *Self, filename: []const u8, pos: Position) *Self {
        if (self.hasFailedWrite) return self;

        if (Ansi) {
            self.safePrint("{s}  at {s}({d}:{d}){s}\n", .{
                Colors.Cyan,
                filename,
                pos.y + 1,
                pos.x + 1,
                Colors.Reset,
            });
        } else {
            self.safePrint("  at {s}({d}:{d})\n", .{ filename, pos.y + 1, pos.x + 1 });
        }
        return self;
    }

    /// Attach a line from a code with a positional hint to the report
    pub fn withLineMsg(self: *Self, code: []const u8, pos: Position, errmsg: []const u8) *Self {
        if (self.hasFailedWrite) return self;

        const line = getLine(pos.y, code);
        std.debug.assert(line != null);

        if (Ansi) {
            self.safePrint("{s}  |  {s}{s}\n", .{ Colors.White, line.?, Colors.Reset });
        } else {
            self.safePrint("  |  {s}\n", .{line.?});
        }

        self.safePrint("     ", .{});
        for (0..pos.x) |_| {
            self.safePrint(" ", .{});
        }

        if (Ansi) {
            self.safePrint("{s}^ {s}{s}\n", .{ Colors.Cyan, errmsg, Colors.Reset });
        } else {
            self.safePrint("^ {s}\n", .{errmsg});
        }
        return self;
    }

    /// Attach an fmt to the report, blank color ANSI.
    pub fn withPrint(
        self: *Self,
        comptime fmt: []const u8,
        args: anytype,
    ) *Self {
        if (self.hasFailedWrite) return self;
        self.safePrint(fmt, args);
        return self;
    }

    /// Try printing on the writer, update hasFailedWrite state if fails
    pub fn safePrint(self: *Self, comptime fmt: []const u8, args: anytype) void {
        if (self.hasFailedWrite) return;

        self.writer.print(fmt, args) catch {
            self.hasFailedWrite = true;
        };
    }

    /// Flush the Writer's buffer, must be attached at the end,
    /// throws WriteFailed if the write has failed along the way
    pub fn flush(self: *Self) error{WriteFailed}!void {
        errdefer self.count -= 1;
        if (self.hasFailedWrite) return error.WriteFailed;
        try self.writer.flush();
    }
};

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

test "chaining" {
    const t = std.testing;
    var buf = std.Io.Writer.Allocating.init(t.allocator);
    defer buf.deinit();
    var err: ErrorReport = .init(&buf.writer);

    const code =
        \\var x = "Hello world!
    ;

    const pos = Position{
        .x = 8,
        .y = 0,
    };

    try err
        .err("Unterminated String")
        .withFileName("main.luv", pos)
        .withLineMsg(code, pos, "this string is unterminated")
        .flush();

    const expected =
        \\{s}[ERR] {s}Unterminated String{s}:
        \\{s}  at main.luv(1:9){s}
        \\{s}  |  var x = "Hello world!{s}
        \\             {s}^ this string is unterminated{s}
        \\
    ;

    try t.expectFmt(buf.writer.buffered(), expected, .{
        Colors.Red,
        Colors.White,
        Colors.Reset,
        Colors.Cyan,
        Colors.Reset,
        Colors.White,
        Colors.Reset,
        Colors.Cyan,
        Colors.Reset,
    });
}

test "Getline" {
    const t = std.testing;
    const gl = getLine;
    const code =
        \\
        \\var x = "Hello world!"
        \\
        \\ 
        // space at the last line
    ;

    try t.expectEqualStrings("", gl(0, code).?);
    try t.expectEqualStrings("var x = \"Hello world!\"", gl(1, code).?);
    try t.expectEqualStrings("", gl(2, code).?);
    try t.expectEqualStrings(" ", gl(3, code).?);
    try t.expect(gl(4, code) == null);
}
