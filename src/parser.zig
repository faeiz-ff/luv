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
    code: ?[]const u8,
    errors: ?luv.ErrorReport,

    /// Do not set or use this variable outside of parser
    result: std.ArrayList(luv.IR),

    /// Do not set or use this variable outside of parser
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
        const lsquare = self.peek(0);
        self.token_index += 1;

        if (self.matchOne(.Rsquare)) {
            self.token_index += 1;

            try self.result.append(self.allocator, .{
                .irtype = .TupleType,
                .token = lsquare,
                .end_offset = 0,
            });

            return;
        }

        const end_index = self.result.items.len;

        try self.typeRule();

        if (self.matchOne(.Comma)) {
            while (self.matchOne(.Comma)) {
                self.token_index += 1;
                try self.typeRule();
            }

            try self.expect(.Rsquare, "Expecting a right square bracket for closing tuple type");
            self.token_index += 1;

            try self.result.append(self.allocator, .{
                .irtype = .TupleType,
                .token = lsquare,
                .end_offset = self.result.items.len - end_index,
            });
        } else {
            try self.expect(.Rsquare, "Expecting a right square bracket for closing type grouping");
            self.token_index += 1;
        }
    }

    fn typBase(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                const end_index = self.result.items.len;

                try self.result.append(self.allocator, .{
                    .irtype = .Identifier,
                    .token = tok,
                    .end_offset = 0,
                });

                self.token_index += 1;

                while (self.matchOne(.Dot)) {
                    const op = self.peek(0);
                    self.token_index += 1;

                    try self.expect(.Identifier, "Expecting an Identifier after a dot '.' in type expression");
                    const rhs = self.peek(0);
                    self.token_index += 1;

                    try self.result.append(self.allocator, .{
                        .irtype = .Identifier,
                        .token = rhs,
                        .end_offset = 0,
                    });

                    try self.result.append(self.allocator, .{
                        .irtype = .DotAccess,
                        .token = op,
                        // this will always anchor to the first identifier
                        .end_offset = self.result.items.len - end_index,
                    });
                }
            },
            .Lsquare => return self.tupleOrGroupingType(),

            // TODO
            else => return error.BadSyntax,
        }
    }

    fn typePostFix(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.typBase();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .irtype = .OptionalType,
                        .token = tok,
                        .end_offset = self.result.items.len - end_index,
                    });
                },
                .Ampersand => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .irtype = .ViewType,
                        .token = tok,
                        .end_offset = self.result.items.len - end_index,
                    });
                },
                .Lsquare => try self.genericFulfillment(end_index),
                else => break,
            }
        }
    }

    fn typeRule(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.typePostFix();

        if (self.matchOne(.Bang)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.typePostFix();

            try self.result.append(self.allocator, .{
                .irtype = .ResultType,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }
    }

    fn genericFulfillment(self: *Parser, end_index: usize) ParseError!void {
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

        while (self.matchOne(.Comma)) {
            self.token_index += 1;
            try self.typeRule();
        }

        try self.expect(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");
        self.token_index += 1;

        try self.result.append(self.allocator, .{
            .irtype = .GenericFulfill,
            .token = lsquare,
            .end_offset = self.result.items.len - end_index,
        });
    }

    fn primaryExpr(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        self.token_index += 1;

        switch (tok.tt) {
            .IntLiteral => try self.result.append(self.allocator, .{
                .irtype = .IntLiteral,
                .token = tok,
                .end_offset = 0,
            }),
            .FloatLiteral => try self.result.append(self.allocator, .{
                .irtype = .FloatLiteral,
                .token = tok,
                .end_offset = 0,
            }),
            .StringLiteral => try self.result.append(self.allocator, .{
                .irtype = .StringLiteral,
                .token = tok,
                .end_offset = 0,
            }),
            .Identifier => try self.result.append(self.allocator, .{
                .irtype = .Identifier,
                .token = tok,
                .end_offset = 0,
            }),
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn dotPostFix(self: *Parser, end_index: usize) ParseError!void {
        const dot = self.peek(0);
        self.token_index += 1;

        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                const id = self.peek(0);
                self.token_index += 1;

                try self.result.append(self.allocator, .{
                    .irtype = .Identifier,
                    .token = id,
                    .end_offset = 0,
                });

                try self.result.append(self.allocator, .{
                    .irtype = .DotAccess,
                    .token = dot,
                    .end_offset = self.result.items.len - end_index,
                });
            },
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn postFixExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.primaryExpr();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .irtype = .QuestionMarkPostFix,
                        .token = tok,
                        .end_offset = self.result.items.len - end_index,
                    });
                },
                .Bang => {
                    self.token_index += 1;
                    try self.result.append(self.allocator, .{
                        .irtype = .BangPostFix,
                        .token = tok,
                        .end_offset = self.result.items.len - end_index,
                    });
                },
                .Lsquare => try self.genericFulfillment(end_index),
                .Dot => try self.dotPostFix(end_index),
                // TODO
                else => break,
            }
        }
    }

    fn unaryExpr(self: *Parser) ParseError!void {
        if (self.match(&[_]luv.TokenType{ .Not, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            const end_index = self.result.items.len;
            try self.unaryExpr();

            try self.result.append(self.allocator, .{
                .irtype = .UnaryPrefix,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        } else {
            try self.postFixExpr();
        }
    }

    fn factorExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.unaryExpr();

        while (self.match(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.unaryExpr();

            try self.result.append(self.allocator, .{
                .irtype = .Arithmetic,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }
    }

    fn termExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.factorExpr();

        while (self.match(&[_]luv.TokenType{ .Plus, .Minus })) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.factorExpr();

            try self.result.append(self.allocator, .{
                .irtype = .Arithmetic,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }
    }

    fn relationalExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.termExpr();

        if (self.match(&[_]luv.TokenType{
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
                .irtype = .Relational,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }

        if (self.match(&[_]luv.TokenType{ .Less, .Greater, .LessEqual, .GreaterEqual, .EqualEqual, .BangEqual })) {
            const tok = self.peek(0);
            self.token_index += 1;

            if (self.errors) |*err| {
                try err.err("Illegal chain of relational expression")
                    .withLineMsg(self.code.?, tok.pos, "use explicit grouping parentheses for this")
                    .flush();
            }
            return error.BadSyntax;
        }
    }

    fn andExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.relationalExpr();

        while (self.matchOne(.And)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.relationalExpr();

            try self.result.append(self.allocator, .{
                .irtype = .LogicBinary,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }
    }

    fn orExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        try self.andExpr();

        while (self.matchOne(.Or)) {
            const tok = self.peek(0);
            self.token_index += 1;

            try self.andExpr();

            try self.result.append(self.allocator, .{
                .irtype = .LogicBinary,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }
    }

    fn assignmentExpr(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
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
                .irtype = .Assignment,
                .token = tok,
                .end_offset = self.result.items.len - end_index,
            });
        }

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

            if (self.errors) |*err| {
                try err.err("Illegal chain of assignment expression")
                    .withLineMsg(self.code.?, tok.pos, "use explicit grouping parentheses for this")
                    .flush();
            }
            return error.BadSyntax;
        }
    }

    fn expression(self: *Parser) ParseError!void {
        return self.assignmentExpr();
    }

    fn topLevelDef(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        const def = self.peek(0);
        self.token_index += 1;

        // TODO def test
        try self.expect(.Identifier, "Expecting identifier after 'def' for top level def statement");
        const id = self.peek(0);
        self.token_index += 1;

        try self.result.append(self.allocator, .{
            .irtype = .Identifier,
            .token = id,
            .end_offset = 0,
        });

        var tok = self.peek(0);
        switch (tok.tt) {
            .Dot => while (tok.tt == .Dot) {
                const dot = self.peek(0);
                self.token_index += 1;

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced id");
                const access = self.peek(0);
                self.token_index += 1;

                try self.result.append(self.allocator, .{
                    .irtype = .Identifier,
                    .token = access,
                    .end_offset = 0,
                });

                try self.result.append(self.allocator, .{
                    .irtype = .DotAccess,
                    .token = dot,
                    .end_offset = self.result.items.len - end_index,
                });

                tok = self.peek(0);
            },
            // TODO destructure
            else => {},
        }

        tok = self.peek(0);
        var isTyped = false;
        switch (tok.tt) {
            .Identifier, .Rsquare => {
                try self.typeRule();
                isTyped = true;
            },
            else => {},
        }

        try self.expect(.Equal, "Expecting '=' after a def declaration, must be initialized");
        self.token_index += 1;

        try self.expression();

        try self.result.append(self.allocator, .{
            .irtype = if (isTyped) .DefDecl else .DefUntypedDecl,
            .token = def,
            .end_offset = self.result.items.len - end_index,
        });
    }

    fn topLevelStatement(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Def => try self.topLevelDef(),
            else => return error.BadSyntax,
        }
    }

    pub fn parse(
        self: *Parser,
        allocator: std.mem.Allocator,
        tokens: []const luv.Token,
    ) ParseError!std.ArrayList(luv.IR) {
        self.tokens = tokens;
        self.result = try .initCapacity(allocator, 32);
        errdefer {
            self.result.deinit(self.allocator);
        }
        self.allocator = allocator;

        // - 1 to account for eof
        while (self.token_index < self.tokens.len - 1) {
            try self.topLevelStatement();
        }

        return self.result;
    }

    pub fn parseExpr(
        self: *Parser,
        allocator: std.mem.Allocator,
        tokens: []const luv.Token,
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

test "top level def" {
    const t = std.testing;

    const code =
        \\ def a b = 10
        \\ def c.d = 20
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parse(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .Identifier, .token = toks.items[1], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .IntLiteral, .token = toks.items[4], .end_offset = 0 },
            .{ .irtype = .DefDecl, .token = toks.items[0], .end_offset = 3 },
            .{ .irtype = .Identifier, .token = toks.items[6], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[8], .end_offset = 0 },
            .{ .irtype = .DotAccess, .token = toks.items[7], .end_offset = 2 },
            .{ .irtype = .IntLiteral, .token = toks.items[10], .end_offset = 0 },
            .{ .irtype = .DefUntypedDecl, .token = toks.items[5], .end_offset = 4 },
        },
        nodelist.items,
    );
}

test "error no leak" {
    const t = std.testing;

    const code =
        \\Parser[Parser[Parser[Parser[[]]]]
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    try t.expectError(error.BadSyntax, p.parseExpr(t.allocator, toks.items));
}

test "postfixes" {
    const t = std.testing;

    const code =
        \\ a?!?!.inner?
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parseExpr(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .Identifier, .token = toks.items[0], .end_offset = 0 },
            .{ .irtype = .QuestionMarkPostFix, .token = toks.items[1], .end_offset = 1 },
            .{ .irtype = .BangPostFix, .token = toks.items[2], .end_offset = 2 },
            .{ .irtype = .QuestionMarkPostFix, .token = toks.items[3], .end_offset = 3 },
            .{ .irtype = .BangPostFix, .token = toks.items[4], .end_offset = 4 },
            .{ .irtype = .Identifier, .token = toks.items[6], .end_offset = 0 },
            .{ .irtype = .DotAccess, .token = toks.items[5], .end_offset = 6 },
            .{ .irtype = .QuestionMarkPostFix, .token = toks.items[7], .end_offset = 7 },
        },
        nodelist.items,
    );
}

test "type dot access" {
    const t = std.testing;
    const code =
        \\ Fraction[ieee.fixed.f8]
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parseExpr(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .Identifier, .token = toks.items[0], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[4], .end_offset = 0 },
            .{ .irtype = .DotAccess, .token = toks.items[3], .end_offset = 2 },
            .{ .irtype = .Identifier, .token = toks.items[6], .end_offset = 0 },
            .{ .irtype = .DotAccess, .token = toks.items[5], .end_offset = 4 },
            .{ .irtype = .GenericFulfill, .token = toks.items[1], .end_offset = 6 },
        },
        nodelist.items,
    );
}

test "exprs with types" {
    const t = std.testing;
    const code =
        \\ a *= b[[u32, i32]] - 10 % 2 == 0
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parseExpr(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .Identifier, .token = toks.items[0], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[5], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[7], .end_offset = 0 },
            .{ .irtype = .TupleType, .token = toks.items[4], .end_offset = 2 },
            .{ .irtype = .GenericFulfill, .token = toks.items[3], .end_offset = 4 },
            .{ .irtype = .IntLiteral, .token = toks.items[11], .end_offset = 0 },
            .{ .irtype = .IntLiteral, .token = toks.items[13], .end_offset = 0 },
            .{ .irtype = .Arithmetic, .token = toks.items[12], .end_offset = 2 },
            .{ .irtype = .Arithmetic, .token = toks.items[10], .end_offset = 8 },
            .{ .irtype = .IntLiteral, .token = toks.items[15], .end_offset = 0 },
            .{ .irtype = .Relational, .token = toks.items[14], .end_offset = 10 },
            .{ .irtype = .Assignment, .token = toks.items[1], .end_offset = 12 },
        },
        nodelist.items,
    );
}

test "basic functionality" {
    const t = std.testing;

    const code =
        \\ c = a + b
    ;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = try p.parseExpr(t.allocator, toks.items);
    defer nodelist.deinit(t.allocator);

    try t.expectEqualSlices(
        luv.IR,
        &[_]luv.IR{
            .{ .irtype = .Identifier, .token = toks.items[0], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[4], .end_offset = 0 },
            .{ .irtype = .Arithmetic, .token = toks.items[3], .end_offset = 2 },
            .{ .irtype = .Assignment, .token = toks.items[1], .end_offset = 4 },
        },
        nodelist.items,
    );
}
