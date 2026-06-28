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
        

    pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
        switch (self.*) {
            // No inner alloc
            .IntLiteral,
            .FloatLiteral,
            .StringLiteral,
            .Identifier,
            => allocator.destroy(self),
            // Binary
            .Arithmetic,
            .Assignment,
            .LogicBinary,
            .Relational,
            .ResultType,
            => |ptr| {
                ptr.lhs.deinit(allocator);
                ptr.rhs.deinit(allocator);
                allocator.destroy(self);
            },
            // Unary
            .UnaryPrefix,
            .QuestionMarkPostFix,
            .BangPostFix,
            .OptionalType,
            .ViewType,
            => |ptr| {
                ptr.node.deinit(allocator);
                allocator.destroy(self);
            },
            // Special
            .GenericFulfill => |*ptr| {
                for (ptr.args.items) |ty| {
                    ty.deinit(allocator);
                }
                ptr.args.deinit(allocator);
                ptr.node.deinit(allocator);
                allocator.destroy(self);
            },
            .DotAccess => |ptr| {
                ptr.lhs.deinit(allocator);
                allocator.destroy(self);
            },
            .TupleType => |*ptr| {
                for (ptr.types.items) |ty| {
                    ty.deinit(allocator);
                }
                ptr.types.deinit(allocator);
                allocator.destroy(self);
            },
        }
    }
};

test "deiniting" {
    const t = std.testing;
    var alloced = try t.allocator.create(AST);
    alloced.* = AST{
        .IntLiteral = luv.Token{
            .lexeme = "1",
            .tt = .IntLiteral,
            .pos = .{ .x = 0, .y = 0 },
        },
    };
    const lhs = alloced;

    alloced = try t.allocator.create(AST);
    alloced.* = AST{
        .IntLiteral = luv.Token{
            .lexeme = "1",
            .tt = .IntLiteral,
            .pos = .{ .x = 0, .y = 0 },
        },
    };
    const rhs = alloced;

    alloced = try t.allocator.create(AST);
    alloced.* = AST{
        .Arithmetic = .{
            .lhs = lhs,
            .op = luv.Token{
                .lexeme = "+",
                .tt = .Plus,
                .pos = .{ .x = 0, .y = 0 },
            },
            .rhs = rhs,
        },
    };
    const ast = alloced;
    defer ast.deinit(t.allocator);
}
