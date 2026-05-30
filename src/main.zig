const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buff: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &buff);
    var stdout = &stdout_file_writer.interface;

    try stdout.print("Hello World!\n", .{});
    try stdout.flush();
}

