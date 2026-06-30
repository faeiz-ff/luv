const std = @import("std");
const luv = @import("root.zig");

pub const IR = union(enum) {
    IntLiteral: luv.Token,
    FloatLiteral: luv.Token,
    StringLiteral: luv.Token,
    Identifier: luv.Token,
    Arithmetic: luv.Token,
    Assignment: luv.Token,
    LogicBinary: luv.Token,
    Relational: luv.Token,
    UnaryPrefix: luv.Token,
    QuestionMarkPostFix: luv.Token,
    BangPostFix: luv.Token,
    GenericFulfill: struct {
        argc: usize,
        lsquare_pos: luv.Position,
    },
    DotAccess: luv.Token,
    TupleType: struct {
        argc: usize,
        lsquare_pos: luv.Position,
    },
    ResultType: luv.Token,
    OptionalType: luv.Token,
    ViewType: luv.Token,
};
