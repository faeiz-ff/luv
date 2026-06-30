const std = @import("std");
const luv = @import("root.zig");

pub const ParseError = error{
    OutOfMemory,
    WriteFailed,
    BadSyntax,
};

pub const ParseResult = struct {
    arena: std.heap.ArenaAllocator,
    ast: *luv.AST,
};

pub const Parser = struct {
    tokens: []const luv.Token,
    token_index: usize,
    code: ?[]const u8,
    errors: ?luv.ErrorReport,

    /// DONT SET THIS UP, RESERVED FOR ARENA ALLOCATOR's CHILD
    /// DONT USE IT OUTSIDE THE STRUCT
    allocator: std.mem.Allocator,

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

    fn matchOne(self: *Parser, tt: luv.TokenType) bool {
        if (self.peek(0).tt == tt) {
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, tt: luv.TokenType, comptime errMsg: []const u8) ParseError!void {
        const tok = self.peek(0);
        if (tok.tt == tt) {
            return;
        }

        if (self.errors) |*err| {
            try err
                .err("Unexpected token")
                .withLineMsg(self.code.?, tok.pos, errMsg)
                .flush();
        }

        return ParseError.BadSyntax;
    }

    fn tupleOrGrouping(self: *Parser) ParseError!*luv.AST {
        const tok = self.peek(0);
        self.token_index += 1;

        if (self.matchOne(.Rsquare)) {
            const rsquare = self.peek(0);
            self.token_index += 1;
            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{
                .TupleType = .{ .types = .empty, .lsquare = tok, .rsquare = rsquare },
            };
            return alloced;
        }

        var typ = try self.typeRule();

        if (self.matchOne(.Comma)) {
            var types: std.ArrayList(*luv.AST) = try .initCapacity(self.allocator, 4);

            try types.append(self.allocator, typ);

            while (self.matchOne(.Comma)) {
                self.token_index += 1;
                typ = try self.typeRule();
                try types.append(self.allocator, typ);
            }

            try self.expect(.Rsquare, "Expecting a right square bracket for closing tuple type");
            const rsquare = self.peek(0);
            self.token_index += 1;

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{
                .TupleType = .{ .types = types, .lsquare = tok, .rsquare = rsquare },
            };
            return alloced;
        }

        try self.expect(.Rsquare, "Expecting a right square bracket for closing type grouping");
        self.token_index += 1;

        return typ;
    }

    fn typBase(self: *Parser) ParseError!*luv.AST {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                var typ = try self.allocator.create(luv.AST);
                typ.* = luv.AST{ .Identifier = tok };

                self.token_index += 1;

                while (self.match(&[_]luv.TokenType{.Dot})) {
                    const op = self.peek(0);
                    self.token_index += 1;

                    try self.expect(.Identifier, "Expecting an Identifier after a dot '.' in type expression");
                    const rhs = self.peek(0);
                    self.token_index += 1;

                    const alloced = try self.allocator.create(luv.AST);
                    alloced.* = luv.AST{ .DotAccess = .{ .lhs = typ, .op = op, .rhs = rhs } };

                    typ = alloced;
                }
                return typ;
            },
            .Lsquare => return self.tupleOrGrouping(),

            // TODO
            else => return error.BadSyntax,
        }
    }

    fn typePostFix(self: *Parser) ParseError!*luv.AST {
        var typ = try self.typBase();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    const alloced = try self.allocator.create(luv.AST);
                    alloced.* = luv.AST{ .OptionalType = .{ .op = tok, .node = typ } };
                    typ = alloced;
                },
                .Ampersand => {
                    self.token_index += 1;
                    const alloced = try self.allocator.create(luv.AST);
                    alloced.* = luv.AST{ .ViewType = .{ .op = tok, .node = typ } };
                    typ = alloced;
                },
                .Lsquare => typ = try self.genericFulfillment(typ),
                else => break,
            }
        }
        return typ;
    }

    fn typeRule(self: *Parser) ParseError!*luv.AST {
        var typ = try self.typePostFix();

        if (self.matchOne(.Bang)) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.typePostFix();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .ResultType = .{ .op = tok, .lhs = typ, .rhs = rhs } };
            typ = alloced;
        }

        return typ;
    }

    fn genericFulfillment(self: *Parser, lhs: *luv.AST) ParseError!*luv.AST {
        const lsquare = self.peek(0);
        self.token_index += 1;

        var typ = try self.typeRule();

        var types: std.ArrayList(*luv.AST) = try .initCapacity(self.allocator, 4);

        try types.append(self.allocator, typ);

        while (self.matchOne(.Comma)) {
            self.token_index += 1;
            typ = try self.typeRule();
            try types.append(self.allocator, typ);
        }

        try self.expect(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");
        const rsquare = self.peek(0);
        self.token_index += 1;

        const alloced = try self.allocator.create(luv.AST);
        alloced.* = luv.AST{
            .GenericFulfill = .{
                .node = lhs,
                .args = types,
                .lsquare = lsquare,
                .rsquare = rsquare,
            },
        };
        return alloced;
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

    fn postFixExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.primaryExpr();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    const alloced = try self.allocator.create(luv.AST);
                    alloced.* = luv.AST{ .QuestionMarkPostFix = .{ .op = tok, .node = expr } };
                    expr = alloced;
                },
                .Bang => {
                    self.token_index += 1;
                    const alloced = try self.allocator.create(luv.AST);
                    alloced.* = luv.AST{ .BangPostFix = .{ .op = tok, .node = expr } };
                    expr = alloced;
                },
                .Lsquare => expr = try self.genericFulfillment(expr),
                // TODO
                else => break,
            }
        }
        return expr;
    }

    fn unaryExpr(self: *Parser) ParseError!*luv.AST {
        if (self.match(&[_]luv.TokenType{ .Not, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.unaryExpr();

            const alloced = try self.allocator.create(luv.AST);
            alloced.* = luv.AST{ .UnaryPrefix = .{ .op = tok, .node = rhs } };
            return alloced;
        } else {
            return self.postFixExpr();
        }
    }

    fn factorExpr(self: *Parser) ParseError!*luv.AST {
        var expr = try self.unaryExpr();

        while (self.match(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const rhs = try self.unaryExpr();

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

        while (self.matchOne(.And)) {
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

        while (self.matchOne(.Or)) {
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

    /// Parse a stream of tokens, if not errored, returns an AST and an ArenaAllocator to destroy it.
    pub fn parse(self: *Parser, allocator: std.mem.Allocator) ParseError!ParseResult {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        self.allocator = arena.allocator();
        const ast = try self.expression();

        return ParseResult{
            .arena = arena,
            .ast = ast,
        };
    }
};

test "error no leak" {
    const t = std.testing;

    const code =
        \\Parser[Parser[Parser[Parser[[]]]]
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .init(toks.items);

    try t.expectError(error.BadSyntax, p.parse(t.allocator));
}

test "generic fulfillment" {
    const t = std.testing;

    const code =
        \\Square[[Fraction, []]]
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .init(toks.items);

    const result = try p.parse(t.allocator);
    defer result.arena.deinit();

    const ast = result.ast;

    var node = ast;
    try t.expect(node.* == .GenericFulfill);
    try t.expect(node.GenericFulfill.node.* == .Identifier);
    try t.expectEqualStrings("Square", node.GenericFulfill.node.Identifier.lexeme);
    try t.expectEqual(1, node.GenericFulfill.args.items.len);

    node = node.GenericFulfill.args.items.ptr[0];
    try t.expect(node.* == .TupleType);
    try t.expectEqual(2, node.TupleType.types.items.len);

    try t.expect(node.TupleType.types.items.ptr[0].* == .Identifier);
    try t.expectEqualStrings("Fraction", node.TupleType.types.items.ptr[0].Identifier.lexeme);

    try t.expect(node.TupleType.types.items.ptr[1].* == .TupleType);
}

test "assignment and arithmetic" {
    const t = std.testing;

    const code =
        \\id = 1 + 1 * 20
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .init(toks.items);

    const result = try p.parse(t.allocator);
    defer result.arena.deinit();

    const ast = result.ast;

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

    const result = try p.parse(t.allocator);
    defer result.arena.deinit();

    const ast = result.ast;
    try t.expect(ast.* == .Arithmetic);
    try t.expect(ast.Arithmetic.lhs.* == .IntLiteral);
    try t.expect(ast.Arithmetic.op.tt == .Plus);
    try t.expect(ast.Arithmetic.rhs.* == .IntLiteral);
}
