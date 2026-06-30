const std = @import("std");
const luv = @import("root.zig");

pub const ParseError = error{
    OutOfMemory,
    WriteFailed,
    BadSyntax,
};

pub const ParseResult = struct {
    arena: std.heap.ArenaAllocator,
    ast: *luv.IR,
};

pub const Parser = struct {
    tokens: []const luv.Token,
    token_index: usize,
    code: ?[]const u8,
    errors: ?luv.ErrorReport,

    /// Do not set or use this outside of parser
    result: std.ArrayList(luv.IR),

    /// Do not set or use this outside of parser
    allocator: std.mem.Allocator,

    pub const empty: Parser = .{
        .tokens = undefined,
        .token_index = 0,
        .allocator = undefined,
        .code = null,
        .errors = null,
        .result = undefined,
    };

    /// set parser custom error writer target
    pub fn assignErr(self: *Parser, code: []const u8, errWriter: *std.Io.Writer) void {
        self.code = code;
        self.errors = .init(errWriter);
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

    fn tupleOrGroupingType(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        self.token_index += 1;

        if (self.matchOne(.Rsquare)) {
            self.token_index += 1;

            try self.result.append(self.allocator, .{
                .TupleType = .{
                    .argc = 0,
                    .lsquare_pos = tok.pos,
                },
            });
            return;
        }

        try self.typeRule();

        if (self.matchOne(.Comma)) {
            var argc: usize = 1;
            while (self.matchOne(.Comma)) {
                argc += 1;
                self.token_index += 1;
                try self.typeRule();
            }

            try self.expect(.Rsquare, "Expecting a right square bracket for closing tuple type");
            self.token_index += 1;

            try self.result.append(self.allocator, .{
                .TupleType = .{
                    .argc = argc,
                    .lsquare_pos = tok.pos,
                },
            });
        } else {
            try self.expect(.Rsquare, "Expecting a right square bracket for closing type grouping");
        }
    }

    fn typBase(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                try self.result.append(self.allocator, .{ .Identifier = tok });
                self.token_index += 1;

                while (self.matchOne(.Dot)) {
                    const op = self.peek(0);
                    self.token_index += 1;

                    try self.expect(.Identifier, "Expecting an Identifier after a dot '.' in type expression");
                    const rhs = self.peek(0);
                    self.token_index += 1;

                    try self.result.append(self.allocator, .{ .Identifier = rhs });

                    try self.result.append(self.allocator, .{ .DotAccess = op });
                }
            },
            .Lsquare => return self.tupleOrGroupingType(),

            // TODO
            else => return error.BadSyntax,
        }
    }

    fn typePostFix(self: *Parser) ParseError!void {
        try self.typBase();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{ .OptionalType = tok });
                },
                .Ampersand => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{ .ViewType = tok });
                },
                .Lsquare => try self.genericFulfillment(),
                else => break,
            }
        }
    }

    fn typeRule(self: *Parser) ParseError!void {
        try self.typePostFix();

        if (self.matchOne(.Bang)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.typePostFix();

            try self.result.append(self.allocator, .{ .ResultType = tok });
        }
    }

    fn genericFulfillment(self: *Parser) ParseError!void {
        const lsquare = self.peek(0);
        self.token_index += 1;

        if (self.matchOne(.Rsquare)) {
            if (self.errors) |*err| {
                try err.err("Expecting non empty generic fulfillment")
                    .withLineMsg(self.code.?, lsquare.pos, "This generic fulfillment is empty")
                    .flush();
            }
            return error.BadSyntax;
        }

        try self.typeRule();

        var argc: usize = 1;
        while (self.matchOne(.Comma)) {
            self.token_index += 1;
            argc += 1;
            try self.typeRule();
        }

        try self.expect(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");
        self.token_index += 1;

        try self.result.append(self.allocator, .{
            .GenericFulfill = .{
                .argc = argc,
                .lsquare_pos = lsquare.pos,
            },
        });
    }

    fn primaryExpr(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        self.token_index += 1;

        switch (tok.tt) {
            .IntLiteral => try self.result.append(self.allocator, .{ .IntLiteral = tok }),
            .FloatLiteral => try self.result.append(self.allocator, .{ .FloatLiteral = tok }),
            .Identifier => try self.result.append(self.allocator, .{ .Identifier = tok }),
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn postFixExpr(self: *Parser) ParseError!void {
        try self.primaryExpr();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .QuestionMarkPostFix = tok,
                    });
                },
                .Bang => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .BangPostFix = tok,
                    });
                },
                .Lsquare => try self.genericFulfillment(),
                // TODO
                else => break,
            }
        }
    }

    fn unaryExpr(self: *Parser) ParseError!void {
        if (self.match(&[_]luv.TokenType{ .Not, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.unaryExpr();

            try self.result.append(self.allocator, .{
                .UnaryPrefix = tok,
            });
        } else {
            try self.postFixExpr();
        }
    }

    fn factorExpr(self: *Parser) ParseError!void {
        try self.unaryExpr();

        while (self.match(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.unaryExpr();

            try self.result.append(self.allocator, .{
                .Arithmetic = tok,
            });
        }
    }

    fn termExpr(self: *Parser) ParseError!void {
        try self.factorExpr();

        while (self.match(&[_]luv.TokenType{ .Plus, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.factorExpr();

            try self.result.append(self.allocator, .{
                .Arithmetic = tok,
            });
        }
    }

    fn relationalExpr(self: *Parser) ParseError!void {
        try self.termExpr();

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

            try self.termExpr();

            try self.result.append(self.allocator, .{
                .Relational = tok,
            });
        }
    }

    fn andExpr(self: *Parser) ParseError!void {
        try self.relationalExpr();

        while (self.matchOne(.And)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.relationalExpr();

            try self.result.append(self.allocator, .{
                .LogicBinary = tok,
            });
        }
    }

    fn orExpr(self: *Parser) ParseError!void {
        try self.andExpr();

        while (self.matchOne(.Or)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.andExpr();

            try self.result.append(self.allocator, .{
                .LogicBinary = tok,
            });
        }
    }

    fn assignmentExpr(self: *Parser) ParseError!void {
        try self.orExpr();

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

            try self.expression();

            try self.result.append(self.allocator, .{
                .Assignment = tok,
            });
        }
    }

    fn expression(self: *Parser) ParseError!void {
        return self.assignmentExpr();
    }

    pub fn parse(
        self: *Parser,
        tokens: []const luv.Token,
        allocator: std.mem.Allocator,
    ) ParseError!std.ArrayList(luv.IR) {
        self.tokens = tokens;
        self.result = try .initCapacity(allocator, 32);
        errdefer {
            self.result.deinit(self.allocator);
        }
        self.allocator = allocator;

        try self.expression();

        return self.result;
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

    var p: Parser = .empty;

    try t.expectError(error.BadSyntax, p.parse(toks.items, t.allocator));
}

test "postfixes" {
    const t = std.testing;

    const code =
        \\ a?!?!
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parse(toks.items, t.allocator);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .Identifier = toks.items[0] },
            .{ .QuestionMarkPostFix = toks.items[1] },
            .{ .BangPostFix = toks.items[2] },
            .{ .QuestionMarkPostFix = toks.items[3] },
            .{ .BangPostFix = toks.items[4] },
        },
        nodelist.items,
    );
}

test "basic functionality" {
    const t = std.testing;

    const code =
        \\ c = a + b
    ;

    var l: luv.Lexer = .init(code);

    var toks = try l.lexAll(t.allocator);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parse(toks.items, t.allocator);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .Identifier = toks.items[0] },
            .{ .Identifier = toks.items[2] },
            .{ .Identifier = toks.items[4] },
            .{ .Arithmetic = toks.items[3] },
            .{ .Assignment = toks.items[1] },
        },
        nodelist.items,
    );
}
