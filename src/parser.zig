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

    fn matchOneAdvance(self: *Parser, tt: luv.TokenType) bool {
        if (self.curr().tt == tt) {
            self.advance();
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        if (self.matchOne(tt)) {
            return;
        }

        const tok = self.curr();
        if (self.errors) |*err| {
            try err
                .err("Unexpected token")
                .withFileName("testing", tok.pos)
                .withLineMsg(self.code.?, tok.pos, errMsg)
                .flush();
        }

        return ParseError.BadSyntax;
    }

    fn expectAdvance(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        if (self.matchOneAdvance(tt)) {
            return;
        }
        try self.expect(tt, errMsg);
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
        const end_index = self.currentIrIndex();
        const lsquare = self.peekThenAdvance();
        var isTuple = false;

        if (self.matchOneAdvance(.Rsquare)) {
            try self.addIR(.TupleType, lsquare, 0);
            return;
        }

        try self.typeRule();

        // the first condition if correct will advance then checks the second condition
        while (self.matchOneAdvance(.Comma) and !self.matchOne(.Rsquare)) {
            try self.typeRule();
            isTuple = true;
        }
        try self.expectAdvance(.Rsquare, "Expecting a right square bracket for closing type");

        if (isTuple) {
            try self.addIR(.TupleType, lsquare, self.currentIrIndex() - end_index);
        }
    }

    fn funParamType(self: *Parser) ParseError!void {
        var hasVariadic = false;
        if (self.matchOne(.Rparen)) return;

        while (true) : (if (!self.matchOneAdvance(.Comma) or hasVariadic or self.matchOne(.Rparen)) break) {
            if (self.matchOne(.DotDot)) {
                const dotdot = self.peekThenAdvance();
                const variadic_end_index = self.currentIrIndex();
                hasVariadic = true;

                try self.typeRule();

                try self.addIR(.RestPrefix, dotdot, self.currentIrIndex() - variadic_end_index);
            } else {
                try self.typeRule();
            }
        }

        if (hasVariadic and self.matchOne(.DotDot)) {
            if (self.errors) |*err| {
                try err
                    .err("Invalid syntax")
                    .withLineMsg(self.code.?, self.curr().pos, "Cannot have multiple variadic parameters")
                    .flush();
            }
            return error.BadSyntax;
        }
    }

    fn funType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fun = self.peekThenAdvance();

        try self.expectAdvance(.Lparen, "Expecting a parentheses for function type parameters");

        try self.funParamType();

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing function type parameters");

        try self.typeRule();

        try self.addIR(.FunType, fun, self.currentIrIndex() - end_index);
    }

    fn symType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const sym = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for sym type");

        var isFirstAttribute = true;
        while (true) : (if (!self.matchOne(.Identifier)) break) {
            if (isFirstAttribute) try self.expect(.Identifier, "Expecting atleast a single identifier for sym type");
            isFirstAttribute = false;

            try self.addIR(.Identifier, self.peekThenAdvance(), 0);

            _ = self.matchOneAdvance(.Comma);
        }

        try self.expectAdvance(.Rbrace, "Expecting a right curly bracket for closing sym type");

        try self.addIR(.SymType, sym, self.currentIrIndex() - end_index);
    }

    fn fitType(self: *Parser, mayGeneric: bool) ParseError!void {
        const end_index = self.currentIrIndex();
        const fit = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for fit type specification");

        if (mayGeneric) {
            // TODO
        }

        const tokens = &[_]luv.TokenType{ .Identifier, .Def };
        var isFirstAttribute = true;

        while (true) : (if (!self.match(tokens)) break) {
            var def: ?luv.Token = null;
            if (self.matchOne(.Def)) {
                def = self.peekThenAdvance();
            }

            if (isFirstAttribute) {
                try self.expect(.Identifier, "Expecting atleast a single attribute in a fit literal type");
            } else {
                try self.expect(.Identifier, "Expecting an Identifier after def attribute decorator in fit literal type");
            }
            isFirstAttribute = false;

            const id_end_index = self.currentIrIndex();
            const id = self.peekThenAdvance();

            if (self.matchOne(.Lparen)) {
                const method_end_index = self.currentIrIndex();
                const tok = self.peekThenAdvance();
                if (def) |_| {
                    if (self.errors) |*err| {
                        try err
                            .err("Redundant syntax")
                            .withLineMsg(self.code.?, id.pos, "This fit attribute is a method, 'def' is redundant")
                            .flush();
                    }
                    return error.BadSyntax;
                }
                try self.funParamType();

                try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing function type parameters");

                try self.typeRule();

                try self.addIR(.FitMethodType, tok, self.currentIrIndex() - method_end_index);
            } else {
                try self.typeRule();
            }

            try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - id_end_index);

            if (def) |tok| {
                try self.addIR(.DefDecorator, tok, self.currentIrIndex() - id_end_index);
            }
            _ = self.matchOneAdvance(.Comma);
        }

        try self.expectAdvance(.Rbrace, "Expecting a right curly bracket for closing fit type");

        try self.addIR(.FitType, fit, self.currentIrIndex() - end_index);
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
            .Fit => return self.fitType(false),
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

        while (self.matchOneAdvance(.Comma) and !self.matchOne(.Rsquare)) {
            try self.typeRule();
        }

        try self.expectAdvance(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");

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
                try self.expectAdvance(.Rparen, "Expecting closing right parentheses");
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

    fn callPostFix(self: *Parser, end_index: usize) ParseError!void {
        const tok = self.peekThenAdvance();
        if (self.matchOneAdvance(.Rparen)) {
            try self.addIR(.CallPostFix, tok, end_index);
            return;
        }

        while (true) : (if (!self.matchOneAdvance(.Comma) or self.matchOne(.Rparen)) break) {
            if (self.matchOne(.DotDot)) {
                const dotdot = self.peekThenAdvance();
                const spread_end_index = self.currentIrIndex();

                try self.expression();

                try self.addIR(.RestPrefix, dotdot, self.currentIrIndex() - spread_end_index);
            } else {
                try self.expression();
            }
        }

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing a function call");

        try self.addIR(.CallPostFix, tok, self.currentIrIndex() - end_index);
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
                .Lparen => try self.callPostFix(end_index),
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

        switch (self.curr().tt) {
            .Dot => while (self.matchOne(.Dot)) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);
            },
            // TODO destructure
            // TODO optionals and view infer
            else => {},
        }

        var isTyped = false;
        if (!self.matchOne(.Equal)) {
            try self.typeRule();
            isTyped = true;
        }

        try self.expectAdvance(.Equal, "Expecting '=' after an identifier in def declaration");

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

        switch (self.curr().tt) {
            .Dot => while (self.matchOne(.Dot)) {
                const dot = self.peekThenAdvance();

                try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
                const access = self.peekThenAdvance();

                try self.addIR(.Identifier, access, 0);

                try self.addIR(.DotAccess, dot, self.result.items.len - end_index);
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
        _ = self.matchOneAdvance(.Semicolon);
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
