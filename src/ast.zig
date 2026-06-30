const std = @import("std");
const luv = @import("root.zig");

pub const AST = union(enum) {
    const Binary = struct {
        lhs: *AST,
        op: luv.Token,
        rhs: *AST,
    };

    const Unary = struct {
        op: luv.Token,
        node: *AST,
    };

    IntLiteral: luv.Token,
    FloatLiteral: luv.Token,
    StringLiteral: luv.Token,
    Identifier: luv.Token,
    Arithmetic: Binary,
    Assignment: Binary,
    LogicBinary: Binary,
    Relational: Binary,
    UnaryPrefix: Unary,
    QuestionMarkPostFix: Unary,
    BangPostFix: Unary,
    GenericFulfill: struct {
        node: *AST,
        args: std.ArrayList(*AST),
        lsquare: luv.Token,
        rsquare: luv.Token,
    },
    DotAccess: struct { lhs: *AST, op: luv.Token, rhs: luv.Token },
    TupleType: struct {
        types: std.ArrayList(*AST),
        lsquare: luv.Token,
        rsquare: luv.Token,
    },
    ResultType: Binary,
    OptionalType: Unary,
    ViewType: Unary,
};
