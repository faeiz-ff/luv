const std = @import("std");
const luv = @import("luv");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.next();

    const mode = args.next();
    if (mode) |m| {
        if (std.mem.eql(u8, m, "run")) {
            const path = args.next() orelse {
                std.debug.print("luv: Usage: luv run FILENAME\n", .{});
                return;
            };

            try runFile(io, path);
        } else {
            std.debug.print("luv: invalid command: {s}\n", .{ m });
        }
    } else {
        std.debug.print("luv: Usage: luv run FILENAME\n", .{});
    }

}

fn runFile(io: std.Io, path: []const u8) !void {
    const allocator = std.heap.smp_allocator;

    var stdout_buff: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buff);
    const stdout = &stdout_file_writer.interface;

    var stderr_buff: [1024]u8 = undefined;
    var stderr_file_writer: std.Io.File.Writer = .init(.stderr(), io, &stderr_buff);
    const stderr = &stderr_file_writer.interface;

    const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var filebuff: [4096]u8 = undefined;
    var reader = file.reader(io, &filebuff);

    var code = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 128);
    defer code.deinit(allocator);

    try reader.interface.appendRemainingUnlimited(allocator, &code);

    var lexer = luv.Lexer.initWithErr(code.items, stderr);
    var tokens = try lexer.lexAll(allocator);
    defer tokens.deinit(allocator);

    for (tokens.items) |tok| {
        try stdout.print("{any}\n", .{tok.tt});
    }
    try stdout.flush();
}

