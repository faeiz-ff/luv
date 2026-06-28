const std = @import("std");
const luv = @import("root.zig");

pub const ParseError = error{
    OutOfMemory,
    WriteFailed,
    BadSyntax,
};

pub const Parser = struct {
    tokens: []const luv.Token,
    token_index: usize,
    allocator: std.mem.Allocator,
    code: ?[]const u8,
    errors: ?luv.ErrorReport,

    /// Initialize Parser with tokens and no error reporting
    pub fn init(tokens: []const luv.Token) Parser {
        return .{
            .tokens = tokens,
            .token_index = 0,
            .allocator = undefined,
            .code = null,
            .errors = null,
        };
    }

    /// Initialize Parser with tokens and custom error writer target
    pub fn initWithErr(
        tokens: []const luv.Token,
        code: []const u8,
        errWriter: *std.Io.Writer,
    ) Parser {
        return .{
            .tokens = tokens,
            .token_index = 0,
            .allocator = undefined,
            .code = code,
            .errors = .init(errWriter),
        };
    }

    pub fn reassignTokens(self: *Parser, tokens: []luv.Token) error{WriteFailed}!void {
        if (self.errors) |err| {
            err.count = 0;
            try err.flush();
        }
        self.tokens = tokens;
        self.token_index = 0;
    }

    fn peek(self: *Parser, num: comptime_int) luv.Token {
        if (self.token_index + num < self.tokens.len) {
            return self.tokens.ptr[self.token_index + num];
        } else {
            return self.tokens.ptr[self.tokens.len - 1];
        }
    }

    fn match(self: *Parser, matches: []const luv.TokenType) bool {
        for (matches) |tt| {
            if (self.peek(0).tt == tt) {
                return true;
            }
        }
        return false;
    }

    fn expect(self: *Parser, tt: luv.TokenType, comptime errMsg: []const u8) ParseError!void {
        const tok = self.peek(0);
        if (tok.tt == tt) {
            return;
        }

        if (self.errors) |err| {
            try err
                .err("Unexpected token")
                .withLineMsg(self.code, tok.pos, errMsg)
                .flush();
        }

        return ParseError.BadSyntax;
    }

    fn primaryExpr(self: *Parser) ParseError!*luv.AST {
        const tok = self.peek(0);
        self.token_index += 1;

        switch (tok.tt) {
            .IntLiteral => {
                const alloced = try self.allocator.create(luv.AST);
                alloced.* = luv.AST{ .IntLiteral = tok };
                return alloced;
            },
            .FloatLiteral => {
                const alloced = try self.allocator.create(luv.AST);
                alloced.* = luv.AST{ .FloatLiteral = tok };
                return alloced;
            },
            .Identifier => {
                const alloced = try self.allocator.create(luv.AST);
                alloced.* = luv.AST{ .Identifier = tok };
                return alloced;
            },
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn unaryExpr(self: *Parser) ParseError!*luv.AST {
        if (self.match(&[_]luv.TokenType{ .Not, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.unaryExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .Unary = .{ .op = tok, .rhs = rhs } };
            return alloced;
        }

        // TODO: should be postfix
        return self.primaryExpr();
    }

    fn factorExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.primaryExpr();

        while (self.match(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.primaryExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .Arithmetic = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn termExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.factorExpr();

        while (self.match(&[_]luv.TokenType{ .Plus, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.factorExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .Arithmetic = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn relationalExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.termExpr();

        while (self.match(&[_]luv.TokenType{
            .Less,
            .Greater,
            .LessEqual,
            .GreaterEqual,
            .EqualEqual,
            .BangEqual,
        })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.termExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .Relational = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn andExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.relationalExpr();

        while (self.match(&[_]luv.TokenType{.And})) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.relationalExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .LogicBinary = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn orExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.andExpr();

        while (self.match(&[_]luv.TokenType{.Or})) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.andExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .LogicBinary = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn assignmentExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.orExpr();

        if (self.match(&[_]luv.TokenType{
            .Equal,
            .PlusEqual,
            .MinusEqual,
            .AsteriskEqual,
            .SolidusEqual,
            .ModulusEqual,
        })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.expression();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .Assignment = .{ .lhs = expr, .op = tok, .rhs = rhs } };
            expr = alloced;
        }

        return expr;
    }

    fn expression(self: *Parser) ParseError!*luv.AST {
        return self.assignmentExpr();
    }

    pub fn parse(self: *Parser, allocator: std.mem.Allocator) ParseError!*luv.AST {
        self.allocator = allocator;
        return self.expression();
    }
};

test "from lexer" {
    const t = std.testing;

    const code =
        \\id = 1 + 1 * 20
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .init(toks.items);

    var ast = try p.parse(t.allocator);
    defer ast.free(t.allocator);
    
    var node = ast;
    try t.expect(node.* == .Assignment);
    try t.expect(node.Assignment.lhs.* == .Identifier);
    try t.expect(node.Assignment.op.tt == .Equal);
    try t.expect(node.Assignment.rhs.* == .Arithmetic);

    node = ast.Assignment.rhs;
    try t.expect(node.Arithmetic.lhs.* == .IntLiteral);
    try t.expect(node.Arithmetic.op.tt == .Plus);
    try t.expect(node.Arithmetic.rhs.* == .Arithmetic);

    node = ast.Assignment.rhs.Arithmetic.rhs;
    try t.expect(node.Arithmetic.lhs.* == .IntLiteral);
    try t.expect(node.Arithmetic.op.tt == .Asterisk);
    try t.expect(node.Arithmetic.rhs.* == .IntLiteral);
}

test "Basic functionality" {
    const t = std.testing;

    const toks: []const luv.Token = &[_]luv.Token{
        luv.Token{
            .lexeme = "1",
            .tt = .IntLiteral,
            .pos = .{ .x = 0, .y = 0 },
        },
        luv.Token{
            .lexeme = "+",
            .tt = .Plus,
            .pos = .{ .x = 1, .y = 0 },
        },
        luv.Token{
            .lexeme = "1",
            .tt = .IntLiteral,
            .pos = .{ .x = 2, .y = 0 },
        },
    };

    var p: Parser = .init(toks);

    const ast = try p.parse(t.allocator);
    defer ast.free(t.allocator);

    try t.expect(ast.* == .Arithmetic);
    try t.expect(ast.Arithmetic.lhs.* == .IntLiteral);
    try t.expect(ast.Arithmetic.op.tt == .Plus);
    try t.expect(ast.Arithmetic.rhs.* == .IntLiteral);
}
