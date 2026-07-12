const std = @import("std");
const luv = @import("luv");

const debug_parsemode = enum {
    Expr,
    FullProgram,
};

/// Given the code, expect the debugtype to be equal to the parsed IR
/// debug_expecteds is a tuple that consists of { irtype, token_index, end_offset }
inline fn debug_expectParseArray(
    comptime code: []const u8,
    comptime debug_expecteds: anytype,
    comptime parse_mode: debug_parsemode,
) !void {
    const t = std.testing;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: luv.Parser = .empty;

    var nodelist = switch (parse_mode) {
        .Expr => try p.parseExpr(t.allocator, toks.items),
        .FullProgram => try p.parse(t.allocator, toks.items),
    };
    defer nodelist.deinit(t.allocator);

    const expecteds = blk: {
        var exs: [debug_expecteds.len]luv.IR = undefined;
        inline for (debug_expecteds, 0..) |ex, i| {
            exs[i] = .{ .irtype = ex.@"0", .token = toks.items[ex.@"1"], .end_offset = ex.@"2" };
        }
        break :blk exs;
    };

    try t.expectEqualSlices(luv.IR, &expecteds, nodelist.items);
}

test "type decl generic decl" {
    const code =
        \\ typ ID[T any] T
        \\ typ Result[T Obj, U Obj] T!U
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 4, 0 },
        .{ .TypedIdentifier, 3, 1 },
        .{ .Identifier, 6, 0 },
        .{ .GenericDeclaration, 2, 3 },
        .{ .TypDecl, 0, 5 },

        .{ .Identifier, 8, 0 },
        .{ .Identifier, 11, 0 },
        .{ .TypedIdentifier, 10, 1 },
        .{ .Identifier, 14, 0 },
        .{ .TypedIdentifier, 13, 1 },
        .{ .Identifier, 16, 0 },
        .{ .Identifier, 18, 0 },
        .{ .ResultType, 17, 2 },
        .{ .GenericDeclaration, 9, 7 },
        .{ .TypDecl, 7, 9 },

        .{ .LuvProgram, 19, 16 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "call postfix" {
    const code =
        \\def a = z()
        \\def b = c(d)
        \\def e = f(g, h, i,)
        \\def j = k(l, ..m)
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .Identifier, 3, 0 },
        .{ .CallPostFix, 4, 1 },
        .{ .DefUntypedDecl, 0, 3 },

        .{ .Identifier, 7, 0 },
        .{ .Identifier, 9, 0 },
        .{ .Identifier, 11, 0 },
        .{ .CallPostFix, 10, 2 },
        .{ .DefUntypedDecl, 6, 4 },

        .{ .Identifier, 14, 0 },
        .{ .Identifier, 16, 0 },
        .{ .Identifier, 18, 0 },
        .{ .Identifier, 20, 0 },
        .{ .Identifier, 22, 0 },
        .{ .CallPostFix, 17, 4 },
        .{ .DefUntypedDecl, 13, 6 },

        .{ .Identifier, 26, 0 },
        .{ .Identifier, 28, 0 },
        .{ .Identifier, 30, 0 },
        .{ .Identifier, 33, 0 },
        .{ .RestPrefix, 32, 1 },
        .{ .CallPostFix, 29, 4 },
        .{ .DefUntypedDecl, 25, 6 },

        .{ .LuvProgram, 35, 23 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "trailing comma" {
    const code =
        \\typ a sym { a, b, }
        \\typ c fit { d e, }
        \\typ f fun (g,) h
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .Identifier, 4, 0 },
        .{ .Identifier, 6, 0 },
        .{ .SymType, 2, 2 },
        .{ .TypDecl, 0, 4 },

        .{ .Identifier, 10, 0 },
        .{ .Identifier, 14, 0 },
        .{ .TypedIdentifier, 13, 1 },
        .{ .FitType, 11, 2 },
        .{ .TypDecl, 9, 4 },

        .{ .Identifier, 18, 0 },
        .{ .Identifier, 21, 0 },
        .{ .Identifier, 24, 0 },
        .{ .FunType, 19, 2 },
        .{ .TypDecl, 17, 4 },
        .{ .LuvProgram, 25, 15 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "fit literal type" {
    const code =
        \\ typ Safe fit {
        \\     def password int&
        \\     money int
        \\     storeMoney(int) nil
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 6, 0 },
        .{ .ViewType, 7, 1 },
        .{ .TypedIdentifier, 5, 2 },
        .{ .DefDecorator, 4, 3 },
        .{ .BuiltinType, 9, 0 },
        .{ .TypedIdentifier, 8, 1 },
        .{ .BuiltinType, 12, 0 },
        .{ .BuiltinType, 14, 0 },
        .{ .FitMethodType, 11, 2 },
        .{ .TypedIdentifier, 10, 3 },
        .{ .FitType, 2, 10 },
        .{ .TypDecl, 0, 12 },
        .{ .LuvProgram, 16, 13 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "sym type" {
    const code =
        \\ typ Status sym {
        \\     Online
        \\     Offline
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .Identifier, 4, 0 },
        .{ .Identifier, 5, 0 },
        .{ .SymType, 2, 2 },
        .{ .TypDecl, 0, 4 },
        .{ .LuvProgram, 7, 5 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "fun type" {
    const code =
        \\typ Adder fun(int, int) int
        \\typ Summer fun(..int) int
        \\typ Fiver fun() int
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 4, 0 },
        .{ .BuiltinType, 6, 0 },
        .{ .BuiltinType, 8, 0 },
        .{ .FunType, 2, 3 },
        .{ .TypDecl, 0, 5 },

        .{ .Identifier, 10, 0 },
        .{ .BuiltinType, 14, 0 },
        .{ .RestPrefix, 13, 1 },
        .{ .BuiltinType, 16, 0 },
        .{ .FunType, 11, 3 },
        .{ .TypDecl, 9, 5 },

        .{ .Identifier, 18, 0 },
        .{ .BuiltinType, 22, 0 },
        .{ .FunType, 19, 1 },
        .{ .TypDecl, 17, 3 },
        .{ .LuvProgram, 23, 16 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "typ decl" {
    const code =
        \\typ Value flo?
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .OptionalType, 3, 1 },
        .{ .TypDecl, 0, 3 },
        .{ .LuvProgram, 4, 4 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "top level def" {
    const code =
        \\ def a int = 10
        \\ def c.d = 20
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .DefDecl, 0, 3 },

        .{ .Identifier, 6, 0 },
        .{ .Identifier, 8, 0 },
        .{ .DotAccess, 7, 2 },
        .{ .IntLiteral, 10, 0 },
        .{ .DefUntypedDecl, 5, 4 },
        .{ .LuvProgram, 11, 9 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "error no leak" {
    const t = std.testing;

    const code =
        \\Parser[Parser[Parser[Parser[[]]]]
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: luv.Parser = .empty;

    try t.expectError(error.BadSyntax, p.parseExpr(t.allocator, toks.items));
}

test "postfixes" {
    const code =
        \\ a?!?!.inner?
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .QuestionMarkPostFix, 1, 1 },
        .{ .BangPostFix, 2, 2 },
        .{ .QuestionMarkPostFix, 3, 3 },
        .{ .BangPostFix, 4, 4 },
        .{ .Identifier, 6, 0 },
        .{ .DotAccess, 5, 6 },
        .{ .QuestionMarkPostFix, 7, 7 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "type dot access" {
    const code =
        \\ Fraction[ieee.fixed.f8]
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 4, 0 },
        .{ .DotAccess, 3, 2 },
        .{ .Identifier, 6, 0 },
        .{ .DotAccess, 5, 4 },
        .{ .GenericFulfillPostFix, 1, 6 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "exprs with types" {
    const code =
        \\ a *= b[[u32, i32]] - 10 % 2 == 0
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 5, 0 },
        .{ .Identifier, 7, 0 },
        .{ .TupleType, 4, 2 },
        .{ .GenericFulfillPostFix, 3, 4 },
        .{ .IntLiteral, 11, 0 },
        .{ .IntLiteral, 13, 0 },
        .{ .Arithmetic, 12, 2 },
        .{ .Arithmetic, 10, 8 },
        .{ .IntLiteral, 15, 0 },
        .{ .Relational, 14, 10 },
        .{ .Assignment, 1, 12 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "basic functionality" {
    const code =
        \\ c = a + b
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 4, 0 },
        .{ .Arithmetic, 3, 2 },
        .{ .Assignment, 1, 4 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}
