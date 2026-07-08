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

    inline fn peekThenAdvance(self: *Parser) luv.Token {
        const tok = self.peek(0);
        self.token_index += 1;
        return tok;
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

    fn expect(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        var tok = self.peek(0);
        if (tok.tt == tt) {
            return;
        }

        tok = self.tokens[self.token_index - 1];
        if (self.errors) |*err| {
            const pos: luv.Position = .{
                .x = tok.pos.x - 1 + @as(u32, @intCast(tok.lexeme.len)),
                .y = tok.pos.y,
            };
            try err
                .err("Unexpected token")
                .withFileName("testing", pos)
                .withLineMsg(self.code.?, pos, errMsg)
                .flush();
        }

        return ParseError.BadSyntax;
    }

    fn addIR(self: *Parser, irtype: luv.IRType, token: luv.Token, end_offset: usize) ParseError!void {
        try self.result.append(self.allocator, .{
            .irtype = irtype,
            .token = token,
            .end_offset = @intCast(end_offset),
        });
    }

    /// literally just self.result.items.len but renamed for intent
    inline fn currentIrIndex(self: *Parser) usize {
        return self.result.items.len;
    }

    fn tupleOrGroupingType(self: *Parser) ParseError!void {
        const lsquare = self.peekThenAdvance();

        if (self.matchOne(.Rsquare)) {
            self.token_index += 1;

            try self.addIR(.TupleType, lsquare, 0);

            return;
        }

        const end_index = self.currentIrIndex();

        try self.typeRule();

        if (self.matchOne(.Comma)) {
            while (self.matchOne(.Comma)) {
                self.token_index += 1;
                try self.typeRule();
            }

            try self.expect(.Rsquare, "Expecting a right square bracket for closing tuple type");
            self.token_index += 1;

            try self.addIR(.TupleType, lsquare, self.currentIrIndex() - end_index);
        } else {
            try self.expect(.Rsquare, "Expecting a right square bracket for closing type grouping");
            self.token_index += 1;
        }
    }

    fn typBase(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                const end_index = self.currentIrIndex();

                try self.addIR(.Identifier, tok, 0);

                self.token_index += 1;

                while (self.matchOne(.Dot)) {
                    const op = self.peekThenAdvance();

                    try self.expect(.Identifier, "Expecting an Identifier after a dot '.' in type expression");
                    const rhs = self.peekThenAdvance();

                    try self.addIR(.Identifier, rhs, 0);

                    // this will always anchor to the first identifier
                    try self.addIR(.DotAccess, op, self.currentIrIndex() - end_index);
                }
            },
            .Lsquare => return self.tupleOrGroupingType(),
            .Int, .Str, .Bol, .Flo, .Nil, .Any => {
                self.token_index += 1;
                try self.addIR(.BuiltinType, tok, 0);
            },
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn typePostFix(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.typBase();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.addIR(.OptionalType, tok, self.currentIrIndex() - end_index);
                },
                .Ampersand => {
                    self.token_index += 1;
                    try self.addIR(.ViewType, tok, self.currentIrIndex() - end_index);
                },
                .Lsquare => try self.genericFulfillment(end_index),
                else => break,
            }
        }
    }

    fn typeRule(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.typePostFix();

        if (self.matchOne(.Bang)) {
            const tok = self.peekThenAdvance();

            try self.typePostFix();

            try self.addIR(.ResultType, tok, self.currentIrIndex() - end_index);
        }
    }

    fn genericFulfillment(self: *Parser, end_index: usize) ParseError!void {
        const lsquare = self.peekThenAdvance();

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

        try self.addIR(.GenericFulfill, lsquare, self.currentIrIndex() - end_index);
    }

    fn primaryExpr(self: *Parser) ParseError!void {
        const tok = self.peekThenAdvance();

        switch (tok.tt) {
            .IntLiteral => try self.addIR(.IntLiteral, tok, 0),
            .FloatLiteral => try self.addIR(.FloatLiteral, tok, 0),
            .StringLiteral => try self.addIR(.StringLiteral, tok, 0),
            .Identifier => try self.addIR(.Identifier, tok, 0),
            // TODO tuple literal
            .Lparen => {
                try self.expression();
                try self.expect(.Rparen, "Expecting closing right parentheses");
                self.token_index += 1;
            },
            .Int, .Str, .Bol, .Flo => try self.addIR(.BuiltinType, tok, 0),
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn dotPostFix(self: *Parser, end_index: usize) ParseError!void {
        const dot = self.peekThenAdvance();

        const tok = self.peek(0);
        switch (tok.tt) {
            .Identifier => {
                const id = self.peekThenAdvance();

                try self.addIR(.Identifier, id, 0);
                try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);
            },
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn postFixExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.primaryExpr();

        while (true) {
            const tok = self.peek(0);
            switch (tok.tt) {
                .QuestionMark => {
                    self.token_index += 1;
                    try self.addIR(.QuestionMarkPostFix, tok, self.currentIrIndex() - end_index);
                },
                .Bang => {
                    self.token_index += 1;
                    try self.addIR(.BangPostFix, tok, self.currentIrIndex() - end_index);
                },
                .Lsquare => try self.genericFulfillment(end_index),
                .Dot => try self.dotPostFix(end_index),
                // TODO
                else => break,
            }
        }
    }

    fn unaryExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        if (self.match(&[_]luv.TokenType{ .Not, .Minus })) {
            const tok = self.peekThenAdvance();

            try self.unaryExpr();

            try self.addIR(.UnaryPrefix, tok, self.currentIrIndex() - end_index);
        } else {
            try self.postFixExpr();
        }
    }

    fn factorExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.unaryExpr();

        while (self.match(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peekThenAdvance();

            try self.unaryExpr();

            try self.addIR(.Arithmetic, tok, self.currentIrIndex() - end_index);
        }
    }

    fn termExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.factorExpr();

        while (self.match(&[_]luv.TokenType{ .Plus, .Minus })) {
            const tok = self.peekThenAdvance();

            try self.factorExpr();

            try self.addIR(.Arithmetic, tok, self.currentIrIndex() - end_index);
        }
    }

    const relationalTokens = &[_]luv.TokenType{
        .Less,
        .Greater,
        .LessEqual,
        .GreaterEqual,
        .EqualEqual,
        .BangEqual,
    };

    fn relationalExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.termExpr();

        if (self.match(relationalTokens)) {
            const tok = self.peekThenAdvance();

            try self.termExpr();

            try self.addIR(.Relational, tok, self.currentIrIndex() - end_index);
        }

        if (self.match(relationalTokens)) {
            const tok = self.peekThenAdvance();

            if (self.errors) |*err| {
                try err.err("Illegal chain of relational expression")
                    .withLineMsg(self.code.?, tok.pos, "use explicit grouping parentheses for this")
                    .flush();
            }
            return error.BadSyntax;
        }
    }

    fn andExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.relationalExpr();

        while (self.matchOne(.And)) {
            const tok = self.peekThenAdvance();

            try self.relationalExpr();

            try self.addIR(.LogicBinary, tok, self.currentIrIndex() - end_index);
        }
    }

    fn orExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.andExpr();

        while (self.matchOne(.Or)) {
            const tok = self.peekThenAdvance();

            try self.andExpr();

            try self.addIR(.LogicBinary, tok, self.currentIrIndex() - end_index);
        }
    }

    const assignmentTokens = &[_]luv.TokenType{
        .Equal,
        .PlusEqual,
        .MinusEqual,
        .AsteriskEqual,
        .SolidusEqual,
        .ModulusEqual,
    };

    fn assignmentExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.orExpr();

        if (self.match(assignmentTokens)) {
            const tok = self.peekThenAdvance();

            try self.expression();

            try self.addIR(.Assignment, tok, self.currentIrIndex() - end_index);
        }
    }

    fn expression(self: *Parser) ParseError!void {
        return self.assignmentExpr();
    }

    fn topLevelDef(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const def = self.peekThenAdvance();

        // TODO def test and exported
        try self.expect(.Identifier, "Expecting identifier after 'def' for top level def statement");
        const id = self.peekThenAdvance();

        try self.addIR(.Identifier, id, 0);

        var tok = self.peek(0);
        switch (tok.tt) {
            .Dot => while (tok.tt == .Dot) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);

                tok = self.peek(0);
            },
            // TODO destructure
            // TODO optionals and view infer
            else => {},
        }

        tok = self.peek(0);
        var isTyped = false;
        switch (tok.tt) {
            .Identifier, .Lsquare, .Int, .Str, .Bol, .Flo, .Nil, .Any => {
                try self.typeRule();
                isTyped = true;
            },
            else => {},
        }

        try self.expect(.Equal, "Expecting '=' after an identifier in def declaration");
        self.token_index += 1;

        try self.expression();

        try self.addIR(if (isTyped) .DefDecl else .DefUntypedDecl, def, self.currentIrIndex() - end_index);
    }

    fn typDecl(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        const typ_tok = self.peekThenAdvance();

        // TODO export modifier
        try self.expect(.Identifier, "Expecting identifier after 'typ' for type declaration");
        const id = self.peekThenAdvance();

        try self.addIR(.Identifier, id, 0);

        var tok = self.peek(0);
        switch (tok.tt) {
            .Dot => while (tok.tt == .Dot) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.result.items.len - end_index);

                tok = self.peek(0);
            },
            else => {},
        }

        try self.typeRule();

        try self.addIR(.TypDecl, typ_tok, self.result.items.len - end_index);
    }

    fn topLevelStatement(self: *Parser) ParseError!void {
        const tok = self.peek(0);
        switch (tok.tt) {
            .Def => try self.topLevelDef(),
            .Typ => try self.typDecl(),
            // TODO
            else => return error.BadSyntax,
        }
        if (self.matchOne(.Semicolon)) self.token_index += 1;
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

        try self.addIR(.LuvProgram, self.peek(0), self.currentIrIndex());

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

test "typ decl" {
    const t = std.testing;

    const code =
        \\typ Value flo?
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
            .{ .irtype = .BuiltinType, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .OptionalType, .token = toks.items[3], .end_offset = 1 },
            .{ .irtype = .TypDecl, .token = toks.items[0], .end_offset = 3 },
            .{ .irtype = .LuvProgram, .token = toks.items[4], .end_offset = 4 },
        },
        nodelist.items,
    );
}

test "top level def" {
    const t = std.testing;

    const code =
        \\ def a int = 10
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
            .{ .irtype = .BuiltinType, .token = toks.items[2], .end_offset = 0 },
            .{ .irtype = .IntLiteral, .token = toks.items[4], .end_offset = 0 },
            .{ .irtype = .DefDecl, .token = toks.items[0], .end_offset = 3 },
            .{ .irtype = .Identifier, .token = toks.items[6], .end_offset = 0 },
            .{ .irtype = .Identifier, .token = toks.items[8], .end_offset = 0 },
            .{ .irtype = .DotAccess, .token = toks.items[7], .end_offset = 2 },
            .{ .irtype = .IntLiteral, .token = toks.items[10], .end_offset = 0 },
            .{ .irtype = .DefUntypedDecl, .token = toks.items[5], .end_offset = 4 },
            .{ .irtype = .LuvProgram, .token = toks.items[11], .end_offset = 9 },
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
