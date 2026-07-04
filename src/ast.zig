const std = @import("std");
const luv = @import("root.zig");

/// Intermediate Representation enum, dictates what the ir type is
/// and what token gets stored
pub const IRType = enum {
    /// Stores int token
    /// Has no child
    IntLiteral,
    /// Stores float token
    /// Has no child
    FloatLiteral,
    /// Stores string token
    /// Has no child
    StringLiteral,
    /// Stores identifier token
    /// Has no child
    Identifier,
    /// Stores arithmetic operation token
    /// Binary, always have two children: lhs and rhs
    Arithmetic,
    /// Stores assignment operation token
    /// Binary, always have two children: lhs and rhs
    Assignment,
    /// Stores logical operation token
    /// Binary, always have two children: lhs and rhs
    LogicBinary,
    /// Stores relational/comparison operation token
    /// Binary, always have two children: lhs and rhs
    Relational,
    /// Stores unary prefix operation token
    /// Unary, always have one child
    UnaryPrefix,
    /// Stores question mark postfix token
    /// Unary, always have one child
    QuestionMarkPostFix,
    /// Stores bang postfix token
    /// Unary, always have one child
    BangPostFix,
    /// Stores left square token that opens generic fulfill
    /// Has variadic number of children
    GenericFulfill,
    /// Stores dot token
    /// Binary, always have two children: base and accessId
    DotAccess,
    /// Stores left square token that opens tuple type
    /// Has variadic number of children
    TupleType,
    /// Stores bang infix type token used on result type
    /// Unary, always have one child
    ResultType,
    /// Stores question mark type token used on optional type
    /// Unary, always have one child
    OptionalType,
    /// Stores ampersand type token used on view type
    /// Unary, always have one child
    ViewType,
    /// Stores var token
    /// Ternary, always have three children: name, type, expr
    VarDecl,
    /// Stores var token
    /// Binary, always have two children: name, expr
    VarUntypedDecl,
    /// Stores def token
    /// Ternary, always have three children: name, type, expr
    DefDecl,
    /// Stores def token
    /// Binary, always have two children: name, expr
    DefUntypedDecl,
};

/// Luv Intermediate Representation to store in an array.
pub const IR = struct {
    irtype: IRType,
    /// The kind of token stored is based on the ir type
    token: luv.Token,
    /// The index offset of the last recursive children of this IR
    /// used for skipping ahead to the next "sibling" node
    /// 0 means this node has no child
    end_offset: usize,
};
