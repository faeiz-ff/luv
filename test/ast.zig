const std = @import("std");
const luv = @import("luv");

test "IR.reverseSlice" {
    const t = std.testing;

    const code =
        \\def tones = 10 + 10
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: luv.Parser = .empty;

    var nodelist = try p.parse(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    luv.IR.reverseSlice(nodelist.items);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .LuvProgram, .token = toks.items[6], .end_offset = 5 },
            .{ .irtype = .DefUntypedDecl, .token = toks.items[0], .end_offset = 4 },
            .{ .irtype = .Identifier, .token = toks.items[1], .end_offset = 0 },
            .{ .irtype = .Arithmetic, .token = toks.items[4], .end_offset = 2 },
            .{ .irtype = .IntLiteral, .token = toks.items[3], .end_offset = 0 },
            .{ .irtype = .IntLiteral, .token = toks.items[5], .end_offset = 0 },
        },
        nodelist.items,
    );
}
