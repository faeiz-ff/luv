const std = @import("std");
const luv = @import("root.zig");

/// Ansi Colors add reset to color it back to normal
pub const Colors = struct {
    pub const Reset = "\x1b[0m";
    pub const Black = "\x1b[0;30;49m";
    pub const BrightBlack = "\x1b[0;90;49m";
    pub const Red = "\x1b[0;31;49m";
    pub const BrightRed = "\x1b[0;91;49m";
    pub const Green = "\x1b[0;32;49m";
    pub const Yellow = "\x1b[0;33;49m";
    pub const Blue = "\x1b[0;34;49m";
    pub const Purple = "\x1b[0;35;49m";
    pub const Cyan = "\x1b[0;36;49m";
    pub const White = "\x1b[0;37;49m";
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
    pub fn err(self: *Self, errheader: []const u8) *Self {
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
    pub fn warn(self: *Self, errheader: []const u8) *Self {
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
    pub fn info(self: *Self, errheader: []const u8) *Self {
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
    pub fn withFileName(self: *Self, filename: []const u8, pos: luv.Position) *Self {
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
    pub fn withLineMsg(self: *Self, code: []const u8, pos: luv.Position, errmsg: []const u8) *Self {
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

pub fn getLine(y_pos: usize, code: []const u8) ?[]const u8 {
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
