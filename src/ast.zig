const std = @import("std");
const luv = @import("luv");

/// Intermediate Representation enum, dictates what the ir type is
/// and what token gets stored
pub const IRType = enum {
    /// Top of the tree marker
    /// Stores eof token
    /// Variadic child of top level statements
    LuvProgram,
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
    /// Starts with the reciever
    GenericFulfillPostFix,
    /// Stores Lparen token that opens call
    /// Has variadic number of children
    /// Starts with the reciever
    CallPostFix,
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
    /// Stores a BuiltinType Token: int, str, bol, flo, nil, any
    /// Has no child
    BuiltinType,
    /// Stores ampersand type token used on view type
    /// Unary, always have one child
    ViewType,
    /// Stores var token
    /// Ternary, always have three children: name or destructure, type, expr
    VarDecl,
    /// Stores var token
    /// Binary, always have two children: name or destructure, expr
    VarUntypedDecl,
    /// Stores def token
    /// Ternary, always have three children: name or destructure, type, expr
    DefDecl,
    /// Stores def token
    /// Binary, always have two children: name or destructure, expr
    DefUntypedDecl,
    /// Stores typ token
    /// Has two or three children: name, optional GenericDeclaration, and typRule
    TypDecl,
    /// Stores fun token
    /// Has variadic number of children
    /// the contents will be types, last of which is the return type
    /// may contain rest prefix before the return type
    FunType,
    /// Stores Lparen token
    /// Has variadic number of children
    /// the contents will be types, last of which is the return type
    /// may contain rest prefix before the return type
    FitMethodType,
    /// Stores dotdot token
    /// Unary, always have one child
    RestPrefix,
    /// Stores sym token
    /// Has variadic number of children
    /// the contents will be identifiers of the symtype
    SymType,
    /// Stores identifier token
    /// Unary, always have one child: the type
    TypedIdentifier,
    /// Stores def token
    /// Unary, always have one child
    DefDecorator,
    /// Stores fit token
    /// Has variadic number of children
    /// the contents will be bare TypedIdentifier
    TagType,
    /// Stores fit token
    /// Has variadic number of children
    /// the contents will be bare TypedIdentifier or a DefDecorated one
    NomType,
    /// Stores fit token
    /// Has variadic number of children
    /// the contents will be bare TypedIdentifier or a DefDecorated one
    FitType,
    /// Stores Lsquare token
    /// Has variadic number of children
    /// the contents will be TypedIdentifiers
    GenericDeclaration,
    /// Stores continue token
    /// Has no child
    ContinueStmt,
    /// Stores Lbrace token
    /// Has variadic number of children: statements
    BlockStmt,
    /// Stores Return token
    /// Has zero or one child: expression
    ReturnStmt,
    /// Stores Break token
    /// Has zero or one child: expression
    BreakStmt,
    /// Stores Yield token
    /// Has zero or one child: expression
    YieldStmt,
    /// Stores fun Token
    /// Has variadic number of elements
    /// follows the rule of:
    /// GenericDeclaration? TypedIdentifier* RestPrefix? TypeRule? BlockStmt
    FunExpr,
    /// Stores Lparen token
    /// Has variadic number of elements: expressions
    TupleExpr,
    /// Stores caret token
    /// Unary, always have one child
    ExportDecorator,
    /// Stores Lbrace token
    /// Has variadic number of elements: Assignment, a DefDecorated one, or RestPrefix
    ObjExpr,
};

/// Luv Intermediate Representation to store in an array.
pub const IR = struct {
    irtype: IRType,
    /// The kind of token stored is based on the ir type
    token: luv.Token,
    /// The index offset of the last recursive children of this IR
    /// used for skipping ahead to the next "sibling" node
    /// 0 means this node has no child
    end_offset: u32,

    /// Used for reversing a slice in place, assumes a valid array IR
    pub fn reverseSlice(arr: []IR) void {
        if (arr.len <= 1) return;
        reverseSliceInner(arr, 0);
    }

    fn reverseSliceInner(arr: []IR, nudge: usize) void {
        if (arr.len == 1) {
            arr.ptr[nudge] = arr[0];
            return;
        }

        const parent_ir = arr[arr.len - 1];

        var child_index = arr.len - 2;
        var child_ir = arr[child_index];

        while (true) {
            reverseSliceInner(
                arr[child_index - child_ir.end_offset .. child_index + 1],
                nudge + 1,
            );

            if (child_index - child_ir.end_offset == 0) break;

            child_index -= child_ir.end_offset + 1;
            child_ir = arr[child_index];
        }

        arr.ptr[nudge] = parent_ir;
    }

    fn printTreeDepth(writer: *std.Io.Writer, arr: []IR, depth: usize) !void {
        for (0..depth) |i| {
            if (i == depth - 1) {
                try writer.print("  > ", .{});
            } else {
                try writer.print("  | ", .{});
            }
        }

        var index: usize = 0;

        const ir = arr[index];
        try writer.print("{s} {s}\n", .{
            @tagName(ir.irtype),
            ir.token.lexeme,
        });

        index += 1;
        while (index < arr.len) {
            const child_ir = arr[index];
            try printTreeDepth(writer, arr[index .. index + child_ir.end_offset + 1], depth + 1);
            index += child_ir.end_offset + 1;
        }
    }

    pub fn printTree(writer: *std.Io.Writer, arr: []IR) !void {
        try printTreeDepth(writer, arr, 0);
    }
};
