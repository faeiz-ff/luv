const std = @import("std");
const luv = @import("luv");

const debug_parsemode = enum {
    Expr,
    Stmt,
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
        .Stmt => try p.parseStmt(t.allocator, toks.items),
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

test "if expr" {
    const code =
        \\ if true {
        \\    return 1
        \\ } elif def b int = 1 and isCondition {
        \\    return 2
        \\ } elif var a = 2 and var b of Circle = a -> 3
        \\ else {
        \\    return 4
        \\ }
    ;

    const expecteds = .{
        .{ .BooleanLiteral, 1, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .ReturnStmt, 3, 1 },
        .{ .BlockStmt, 2, 2 },

        .{ .Identifier, 8, 0 },
        .{ .BuiltinType, 9, 0 },
        .{ .IntLiteral, 11, 0 },
        .{ .DefDecl, 7, 3 },
        .{ .Identifier, 13, 0 },
        .{ .IntLiteral, 16, 0 },
        .{ .ReturnStmt, 15, 1 },
        .{ .BlockStmt, 14, 2 },

        .{ .Identifier, 20, 0 },
        .{ .IntLiteral, 22, 0 },
        .{ .VarUntypedDecl, 19, 2 },
        .{ .Identifier, 25, 0 },
        .{ .Identifier, 27, 0 },
        .{ .OfPrefix, 26, 1 },
        .{ .Identifier, 29, 0 },
        .{ .VarDecl, 24, 4 },
        .{ .IntLiteral, 31, 0 },
        .{ .YieldStmt, 30, 1 },

        .{ .IntLiteral, 35, 0 },
        .{ .ReturnStmt, 34, 1 },
        .{ .BlockStmt, 33, 2 },
        .{ .IfExpr, 32, 3 },

        .{ .IfExpr, 18, 14 },

        .{ .IfExpr, 6, 23 },

        .{ .IfExpr, 0, 28 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "infer optional view" {
    const code =
        \\ def a? = 1
        \\
        \\ fun main() {
        \\     def b& = 2
        \\ }
    ;

    const expected = .{
        .{ .Identifier, 1, 0 },
        .{ .OptionalType, 2, 1 },
        .{ .IntLiteral, 4, 0 },
        .{ .DefUntypedDecl, 0, 3 },

        .{ .Identifier, 6, 0 },
        .{ .Identifier, 11, 0 },
        .{ .ViewType, 12, 1 },
        .{ .IntLiteral, 14, 0 },
        .{ .DefUntypedDecl, 10, 3 },
        .{ .BlockStmt, 9, 4 },
        .{ .FunExpr, 5, 5 },
        .{ .DefUntypedDecl, 5, 7 },

        .{ .LuvProgram, 16, 12 },
    };

    try debug_expectParseArray(code, expected, .FullProgram);
}

test "tuple destructure" {
    const code =
        \\ {
        \\     var a, b = thing
        \\     def a, b [int, flo] = thing2
        \\ }
    ;

    const expected = .{
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 4, 0 },
        .{ .TupleType, 3, 2 },
        .{ .Identifier, 6, 0 },
        .{ .VarUntypedDecl, 1, 4 },

        .{ .Identifier, 8, 0 },
        .{ .Identifier, 10, 0 },
        .{ .TupleType, 9, 2 },
        .{ .BuiltinType, 12, 0 },
        .{ .BuiltinType, 14, 0 },
        .{ .TupleType, 11, 2 },
        .{ .Identifier, 17, 0 },
        .{ .DefDecl, 7, 7 },

        .{ .BlockStmt, 0, 13 },
    };

    try debug_expectParseArray(code, expected, .Stmt);
}

test "obj expression" {
    const code =
        \\ {
        \\     b = 1
        \\     def c = 0, 
        \\     ..opt,
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .IntLiteral, 3, 0 },
        .{ .Assignment, 2, 2 },

        .{ .Identifier, 5, 0 },
        .{ .IntLiteral, 7, 0 },
        .{ .Assignment, 6, 2 },
        .{ .DefDecorator, 4, 3 },

        .{ .Identifier, 10, 0 },
        .{ .RestPrefix, 9, 1 },

        .{ .ObjExpr, 0, 9 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "export" {
    const code =
        \\ def ^a = 1
        \\ fun ^b (){}
        \\ typ ^c nom {
        \\     ^a int 
        \\     def ^b int 
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .DefUntypedDecl, 0, 2 },
        .{ .ExportDecorator, 1, 3 },

        .{ .Identifier, 7, 0 },
        .{ .BlockStmt, 10, 0 },
        .{ .FunExpr, 5, 1 },
        .{ .DefUntypedDecl, 5, 3 },
        .{ .ExportDecorator, 6, 4 },

        .{ .Identifier, 14, 0 },
        .{ .BuiltinType, 19, 0 },
        .{ .TypedIdentifier, 18, 1 },
        .{ .ExportDecorator, 17, 2 },
        .{ .BuiltinType, 23, 0 },
        .{ .TypedIdentifier, 22, 1 },
        .{ .DefDecorator, 20, 2 },
        .{ .ExportDecorator, 21, 3 },
        .{ .NomType, 15, 7 },
        .{ .TypDecl, 12, 9 },
        .{ .ExportDecorator, 13, 10 },

        .{ .LuvProgram, 25, 20 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "tuple expression" {
    const code =
        \\ ((1 + 1,), (1), (1,2,), ())
    ;

    const expecteds = .{
        .{ .IntLiteral, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .Arithmetic, 3, 2 },
        .{ .TupleExpr, 1, 3 },

        .{ .IntLiteral, 9, 0 },

        .{ .IntLiteral, 13, 0 },
        .{ .IntLiteral, 15, 0 },
        .{ .TupleExpr, 12, 2 },

        .{ .TupleExpr, 19, 0 },

        .{ .TupleExpr, 0, 9 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "top level fun" {
    const code =
        \\ fun main() {
        \\     print("Hello World")
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .Identifier, 5, 0 },
        .{ .StringLiteral, 7, 0 },
        .{ .CallPostFix, 6, 2 },
        .{ .BlockStmt, 4, 3 },
        .{ .FunExpr, 0, 4 },
        .{ .DefUntypedDecl, 0, 6 },
        .{ .LuvProgram, 10, 7 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "fun expr" {
    const code =
        \\ fun [T any](a T, ..b T) T { return a + b }
    ;

    const expecteds = .{
        .{ .BuiltinType, 3, 0 },
        .{ .TypedIdentifier, 2, 1 },
        .{ .GenericDeclaration, 1, 2 },

        .{ .Identifier, 7, 0 },
        .{ .TypedIdentifier, 6, 1 },

        .{ .Identifier, 11, 0 },
        .{ .TypedIdentifier, 10, 1 },
        .{ .RestPrefix, 9, 2 },

        .{ .Identifier, 13, 0 },

        .{ .Identifier, 16, 0 },
        .{ .Identifier, 18, 0 },
        .{ .Arithmetic, 17, 2 },
        .{ .ReturnStmt, 15, 3 },
        .{ .BlockStmt, 14, 4 },

        .{ .FunExpr, 0, 14 },
    };
    try debug_expectParseArray(code, expecteds, .Expr);
}

test "block stmt" {
    const code =
        \\ {
        \\    var a int = 10
        \\    a += 20
        \\    return a
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 2, 0 },
        .{ .BuiltinType, 3, 0 },
        .{ .IntLiteral, 5, 0 },
        .{ .VarDecl, 1, 3 },
        .{ .Identifier, 6, 0 },
        .{ .IntLiteral, 8, 0 },
        .{ .Assignment, 7, 2 },
        .{ .Identifier, 10, 0 },
        .{ .ReturnStmt, 9, 1 },
        .{ .BlockStmt, 0, 9 },
    };

    try debug_expectParseArray(code, expecteds, .Stmt);
}

test "def stmt" {
    const code =
        \\ def a = 10
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .IntLiteral, 3, 0 },
        .{ .DefUntypedDecl, 0, 2 },
    };

    try debug_expectParseArray(code, expecteds, .Stmt);

    const code2 =
        \\ def a int = 10
    ;

    const expecteds2 = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .DefDecl, 0, 3 },
    };

    try debug_expectParseArray(code2, expecteds2, .Stmt);
}

test "var stmt" {
    const code =
        \\ var a = 10
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .IntLiteral, 3, 0 },
        .{ .VarUntypedDecl, 0, 2 },
    };

    try debug_expectParseArray(code, expecteds, .Stmt);

    const code2 =
        \\ var a int = 10
    ;

    const expecteds2 = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .VarDecl, 0, 3 },
    };

    try debug_expectParseArray(code2, expecteds2, .Stmt);
}

test "tag type" {
    const code =
        \\ typ Shape tag {
        \\     Cicle int
        \\     Rect  [int, int]
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 5, 0 },
        .{ .TypedIdentifier, 4, 1 },
        .{ .BuiltinType, 8, 0 },
        .{ .BuiltinType, 10, 0 },
        .{ .TupleType, 7, 2 },
        .{ .TypedIdentifier, 6, 3 },
        .{ .TagType, 2, 6 },
        .{ .TypDecl, 0, 8 },
        .{ .LuvProgram, 13, 9 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "nom type" {
    const code =
        \\ typ a nom {}
        \\ typ box nom {
        \\     thing int
        \\     def constantThing int
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .NomType, 2, 0 },
        .{ .TypDecl, 0, 2 },

        .{ .Identifier, 6, 0 },
        .{ .BuiltinType, 10, 0 },
        .{ .TypedIdentifier, 9, 1 },
        .{ .BuiltinType, 13, 0 },
        .{ .TypedIdentifier, 12, 1 },
        .{ .DefDecorator, 11, 2 },
        .{ .NomType, 7, 5 },
        .{ .TypDecl, 5, 7 },

        .{ .LuvProgram, 15, 11 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
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
        .{ .GenericDeclaration, 2, 2 },
        .{ .Identifier, 6, 0 },
        .{ .TypDecl, 0, 5 },

        .{ .Identifier, 8, 0 },
        .{ .Identifier, 11, 0 },
        .{ .TypedIdentifier, 10, 1 },
        .{ .Identifier, 14, 0 },
        .{ .TypedIdentifier, 13, 1 },
        .{ .GenericDeclaration, 9, 4 },
        .{ .Identifier, 16, 0 },
        .{ .Identifier, 18, 0 },
        .{ .ResultType, 17, 2 },
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
