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

    fn curr(self: *Parser) luv.Token {
        return self.tokens.ptr[self.token_index];
    }

    fn advance(self: *Parser) void {
        if (self.token_index < self.tokens.len - 1) {
            self.token_index += 1;
        }
    }

    inline fn peekThenAdvance(self: *Parser) luv.Token {
        const tok = self.curr();
        self.advance();
        return tok;
    }

    fn match(self: *Parser, matches: []const luv.TokenType) bool {
        for (matches) |tt| {
            if (self.curr().tt == tt) {
                return true;
            }
        }
        return false;
    }

    fn matchOne(self: *Parser, tt: luv.TokenType) bool {
        if (self.curr().tt == tt) {
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        var tok = self.curr();
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
            self.advance();

            try self.addIR(.TupleType, lsquare, 0);

            return;
        }

        const end_index = self.currentIrIndex();

        try self.typeRule();

        if (self.matchOne(.Comma)) {
            while (self.matchOne(.Comma)) {
                self.advance();
                try self.typeRule();
            }

            try self.expect(.Rsquare, "Expecting a right square bracket for closing tuple type");
            self.advance();

            try self.addIR(.TupleType, lsquare, self.currentIrIndex() - end_index);
        } else {
            try self.expect(.Rsquare, "Expecting a right square bracket for closing type grouping");
            self.advance();
        }
    }

    fn funType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fun = self.peekThenAdvance();

        try self.expect(.Lparen, "Expecting a parentheses for function type parameters");
        self.advance();

        var tok = self.curr();
        var hasVariadic = false;
        if (tok.tt == .DotDot) {
            self.advance();
            hasVariadic = true;
        }

        try self.typeRule();

        tok = self.curr();
        while (tok.tt == .Comma and !hasVariadic) {
            self.advance();
            tok = self.curr();
            if (tok.tt == .DotDot) {
                self.advance();
                hasVariadic = true;
            }

            try self.typeRule();

            tok = self.curr();
        }

        try self.expect(.Rparen, "Expecting a right parentheses for closing function type parameters");
        self.advance();

        try self.typeRule();

        try self.addIR(if (hasVariadic) .FunVariadicType else .FunType, fun, self.currentIrIndex() - end_index);
    }

    fn symType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const sym = self.peekThenAdvance();

        try self.expect(.Lbrace, "Expecting curly brackets for sym type");
        self.advance();

        try self.expect(.Identifier, "Expecting atleast a single identifier for sym type");
        try self.addIR(.Identifier, self.peekThenAdvance(), 0);

        if (self.matchOne(.Comma)) self.advance();

        var tok = self.curr();
        while (tok.tt == .Identifier) {
            try self.addIR(.Identifier, self.peekThenAdvance(), 0);
            if (self.matchOne(.Comma)) self.advance();
            tok = self.curr();
        }

        try self.expect(.Rbrace, "Expecting a right curly bracket for closing sym type");
        self.advance();

        try self.addIR(.SymType, sym, self.currentIrIndex() - end_index);
    }

    fn typeBase(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Identifier => {
                const end_index = self.currentIrIndex();

                try self.addIR(.Identifier, tok, 0);

                self.advance();

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
                self.advance();
                try self.addIR(.BuiltinType, tok, 0);
            },
            .Fun => return self.funType(),
            .Sym => return self.symType(),
            // TODO
            else => return error.BadSyntax,
        }
    }

    fn typePostFix(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.typeBase();

        while (true) {
            const tok = self.curr();
            switch (tok.tt) {
                .QuestionMark => {
                    self.advance();
                    try self.addIR(.OptionalType, tok, self.currentIrIndex() - end_index);
                },
                .Ampersand => {
                    self.advance();
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
            self.advance();
            try self.typeRule();
        }

        try self.expect(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");
        self.advance();

        try self.addIR(.GenericFulfillPostFix, lsquare, self.currentIrIndex() - end_index);
    }

    fn primaryExpr(self: *Parser) ParseError!void {
        const tok = self.curr();

        switch (tok.tt) {
            .IntLiteral => {
                self.advance();
                try self.addIR(.IntLiteral, tok, 0);
            },
            .FloatLiteral => {
                self.advance();
                try self.addIR(.FloatLiteral, tok, 0);
            },
            .StringLiteral => {
                self.advance();
                try self.addIR(.StringLiteral, tok, 0);
            },
            .Identifier => {
                self.advance();
                try self.addIR(.Identifier, tok, 0);
            },
            // TODO tuple literal
            .Lparen => {
                self.advance();
                try self.expression();
                try self.expect(.Rparen, "Expecting closing right parentheses");
                self.advance();
            },
            .Int, .Str, .Bol, .Flo => {
                self.advance();
                try self.addIR(.BuiltinType, tok, 0);
            },

            // TODO
            else => return error.BadSyntax,
        }
    }

    fn dotPostFix(self: *Parser, end_index: usize) ParseError!void {
        const dot = self.peekThenAdvance();

        const tok = self.curr();
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
            const tok = self.curr();
            switch (tok.tt) {
                .QuestionMark => {
                    self.advance();
                    try self.addIR(.QuestionMarkPostFix, tok, self.currentIrIndex() - end_index);
                },
                .Bang => {
                    self.advance();
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

        var tok = self.curr();
        switch (tok.tt) {
            .Dot => while (tok.tt == .Dot) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);

                tok = self.curr();
            },
            // TODO destructure
            // TODO optionals and view infer
            else => {},
        }

        tok = self.curr();
        var isTyped = false;
        switch (tok.tt) {
            .Equal => {},
            else => {
                try self.typeRule();
                isTyped = true;
            },
        }

        try self.expect(.Equal, "Expecting '=' after an identifier in def declaration");
        self.advance();

        try self.expression();

        try self.addIR(if (isTyped) .DefDecl else .DefUntypedDecl, def, self.currentIrIndex() - end_index);
    }

    fn typeDecl(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        const typ_tok = self.peekThenAdvance();

        // TODO export modifier
        try self.expect(.Identifier, "Expecting identifier after 'typ' for type declaration");
        const id = self.peekThenAdvance();

        try self.addIR(.Identifier, id, 0);

        var tok = self.curr();
        switch (tok.tt) {
            .Dot => while (tok.tt == .Dot) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.result.items.len - end_index);

                tok = self.curr();
            },
            else => {},
        }

        try self.typeRule();

        try self.addIR(.TypDecl, typ_tok, self.result.items.len - end_index);
    }

    fn topLevelStatement(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Def => try self.topLevelDef(),
            .Typ => try self.typeDecl(),
            // TODO
            else => return error.BadSyntax,
        }
        if (self.matchOne(.Semicolon)) self.advance();
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

        try self.addIR(.LuvProgram, self.curr(), self.currentIrIndex());

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

const debug_parsemode = enum {
    Expr,
    FullProgram,
};

/// Given the code, expect the debugtype to be equal to the parsed IR
/// debug_expecteds is a tuple that consists of { irtype, token_index, end_offset }
inline fn debug_expectParseArray(
    comptime code: []const u8,
    comptime debug_expecteds: anytype,
    comptime parse_mode: debug_parsemode,
) !void {
    const t = std.testing;

    var l: luv.Lexer = .empty;

    var toks = try l.lexAll(t.allocator, code);
    defer toks.deinit(t.allocator);

    var p: Parser = .empty;

    var nodelist = switch (parse_mode) {
        .Expr => try p.parseExpr(t.allocator, toks.items),
        .FullProgram => try p.parse(t.allocator, toks.items),
    };
    defer nodelist.deinit(t.allocator);

    const expecteds = blk: {
        var exs: [debug_expecteds.len]luv.IR = undefined;
        inline for (debug_expecteds, 0..) |ex, i| {
            exs[i] = .{ .irtype = ex.@"0", .token = toks.items[ex.@"1"], .end_offset = ex.@"2" };
        }
        break :blk exs;
    };

    try t.expectEqualSlices(luv.IR, &expecteds, nodelist.items);
}

test "sym type" {
    const code =
        \\ typ Status sym {
        \\     Online
        \\     Offline
        \\ }
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .Identifier, 4, 0 },
        .{ .Identifier, 5, 0 },
        .{ .SymType, 2, 2 },
        .{ .TypDecl, 0, 4 },
        .{ .LuvProgram, 7, 5 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "fun type" {
    const code =
        \\typ Adder fun(int, int) int
        \\typ Summer fun(..int) int
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 4, 0 },
        .{ .BuiltinType, 6, 0 },
        .{ .BuiltinType, 8, 0 },
        .{ .FunType, 2, 3 },
        .{ .TypDecl, 0, 5 },

        .{ .Identifier, 10, 0 },
        .{ .BuiltinType, 14, 0 },
        .{ .BuiltinType, 16, 0 },
        .{ .FunVariadicType, 11, 2 },
        .{ .TypDecl, 9, 4 },
        .{ .LuvProgram, 17, 11 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "typ decl" {
    const code =
        \\typ Value flo?
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .OptionalType, 3, 1 },
        .{ .TypDecl, 0, 3 },
        .{ .LuvProgram, 4, 4 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
}

test "top level def" {
    const code =
        \\ def a int = 10
        \\ def c.d = 20
    ;

    const expecteds = .{
        .{ .Identifier, 1, 0 },
        .{ .BuiltinType, 2, 0 },
        .{ .IntLiteral, 4, 0 },
        .{ .DefDecl, 0, 3 },

        .{ .Identifier, 6, 0 },
        .{ .Identifier, 8, 0 },
        .{ .DotAccess, 7, 2 },
        .{ .IntLiteral, 10, 0 },
        .{ .DefUntypedDecl, 5, 4 },
        .{ .LuvProgram, 11, 9 },
    };

    try debug_expectParseArray(code, expecteds, .FullProgram);
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
    const code =
        \\ a?!?!.inner?
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .QuestionMarkPostFix, 1, 1 },
        .{ .BangPostFix, 2, 2 },
        .{ .QuestionMarkPostFix, 3, 3 },
        .{ .BangPostFix, 4, 4 },
        .{ .Identifier, 6, 0 },
        .{ .DotAccess, 5, 6 },
        .{ .QuestionMarkPostFix, 7, 7 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "type dot access" {
    const code =
        \\ Fraction[ieee.fixed.f8]
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 4, 0 },
        .{ .DotAccess, 3, 2 },
        .{ .Identifier, 6, 0 },
        .{ .DotAccess, 5, 4 },
        .{ .GenericFulfillPostFix, 1, 6 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "exprs with types" {
    const code =
        \\ a *= b[[u32, i32]] - 10 % 2 == 0
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 5, 0 },
        .{ .Identifier, 7, 0 },
        .{ .TupleType, 4, 2 },
        .{ .GenericFulfillPostFix, 3, 4 },
        .{ .IntLiteral, 11, 0 },
        .{ .IntLiteral, 13, 0 },
        .{ .Arithmetic, 12, 2 },
        .{ .Arithmetic, 10, 8 },
        .{ .IntLiteral, 15, 0 },
        .{ .Relational, 14, 10 },
        .{ .Assignment, 1, 12 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}

test "basic functionality" {
    const code =
        \\ c = a + b
    ;

    const expecteds = .{
        .{ .Identifier, 0, 0 },
        .{ .Identifier, 2, 0 },
        .{ .Identifier, 4, 0 },
        .{ .Arithmetic, 3, 2 },
        .{ .Assignment, 1, 4 },
    };

    try debug_expectParseArray(code, expecteds, .Expr);
}
