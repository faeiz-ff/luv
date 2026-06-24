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

    var buff: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &buff);
    const stdout = &stdout_file_writer.interface;

    const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var filebuff: [4096]u8 = undefined;
    var reader = file.reader(io, &filebuff);

    var buffer = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 128);
    defer buffer.deinit(allocator);

    try reader.interface.appendRemainingUnlimited(allocator, &buffer);

    var lexer = luv.Lexer.empty;
    var tokens = lexer.lex(allocator, buffer.items) catch |err| switch (err) {
        else => return,
    };
    defer tokens.deinit(allocator);

    for (tokens.items) |tok| {
        try stdout.print("{any}\n", .{tok.tt});
    }
    try stdout.flush();
}

