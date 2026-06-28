const std = @import("std");
const luv = @import("root.zig");

pub const AST = union(enum) {
    const Binary = struct {
        lhs: *AST,
        op: luv.Token,
        rhs: *AST,
    };

    IntLiteral: luv.Token,
    FloatLiteral: luv.Token,
    StringLiteral: luv.Token,
    Identifier: luv.Token,
    Arithmetic: Binary,
    Assignment: Binary,
    LogicBinary: Binary,
    Relational: Binary,
    Unary: struct { op: luv.Token, rhs: *AST },

    pub fn free(self: *AST, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .IntLiteral,
            .FloatLiteral,
            .StringLiteral,
            .Identifier,
            => allocator.destroy(self),
            .Arithmetic,
            .Assignment,
            .LogicBinary,
            .Relational,
            => |ptr| { 
                ptr.lhs.free(allocator);
                ptr.rhs.free(allocator);
                allocator.destroy(self);
            },
            .Unary => |ptr| {
                ptr.rhs.free(allocator);
                allocator.destroy(self);
            },
        }
    }
};

test "freeing" {
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
    defer ast.free(t.allocator);
}
