const std = @import("std");
const luv = @import("luv");

test "chaining" {
    const t = std.testing;
    var buf = std.Io.Writer.Allocating.init(t.allocator);
    defer buf.deinit();
    var err: luv.ErrorReport = .init(&buf.writer);

    const code =
        \\var x = "Hello world!
    ;

    const pos = luv.Position{
        .x = 8,
        .y = 0,
    };

    try err
        .report(.Err ,"Unterminated String")
        .withFileName("main.luv")
        .withLineMsg(code, pos, "this string is unterminated")
        .flush();

    const expected =
        \\{s}[Err] {s}Unterminated String:
        \\{s}  at main.luv
        \\{s}  at line 1
        \\{s}  |  var x = "Hello world!
        \\             {s}^ this string is unterminated
        \\{s}
    ;

    try t.expectFmt(buf.writer.buffered(), expected, .{
        luv.Colors.Red,
        luv.Colors.White,
        luv.Colors.Cyan,
        luv.Colors.Cyan,
        luv.Colors.White,
        luv.Colors.Cyan,
        luv.Colors.Reset,
    });
}

test "Getline" {
    const t = std.testing;
    const gl = luv.getLine;
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
