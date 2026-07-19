const std = @import("std");
const luv = @import("luv");

pub const ParseError = error{
    OutOfMemory,
    WriteFailed,
    BadSyntax,
};

pub const Parser = struct {
    tokens: []const luv.Token,
    token_index: usize,
    errors: ?luv.ParserErrorReport,

    /// Do not set or use this variable outside of parser
    result: std.ArrayList(luv.IR),

    /// Do not set or use this variable outside of parser
    allocator: std.mem.Allocator,

    pub const empty: Parser = .{
        .tokens = undefined,
        .token_index = 0,
        .allocator = undefined,
        .errors = null,
        .result = undefined,
    };

    /// set parser custom error writer target
    pub fn assignErr(self: *Parser, code: []const u8, errWriter: *std.Io.Writer) void {
        self.errors = .init(code, errWriter);
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

    fn peekThenAdvance(self: *Parser) luv.Token {
        const tok = self.curr();
        self.advance();
        return tok;
    }

    fn matchAny(self: *Parser, matches: []const luv.TokenType) bool {
        for (matches) |tt| {
            if (self.curr().tt == tt) {
                return true;
            }
        }
        return false;
    }

    fn match(self: *Parser, tt: luv.TokenType) bool {
        if (self.curr().tt == tt) {
            return true;
        }
        return false;
    }

    fn matchThenAdvance(self: *Parser, tt: luv.TokenType) bool {
        if (self.curr().tt == tt) {
            self.advance();
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        if (self.match(tt)) {
            return;
        }

        const tok = self.curr();
        if (self.errors) |*err| try err.errorUnexpectedToken(
            tok.pos,
            errMsg,
        );

        return error.BadSyntax;
    }

    fn expectAdvance(self: *Parser, tt: luv.TokenType, errMsg: []const u8) ParseError!void {
        if (self.matchThenAdvance(tt)) {
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

    /// returns true if theres a comma ahead and its not followed by a bracket_type
    /// commas will be consumed if it exists either way
    fn consumeCommaAndNotMatch(self: *Parser, bracket_type: luv.TokenType) bool {
        if (self.matchThenAdvance(.Comma) and !self.match(bracket_type)) {
            return true;
        }
        return false;
    }

    fn vardefIRChooseFrom(tt: luv.TokenType, typed: bool) luv.IRType {
        if (tt == .Var) {
            if (typed) return .VarDecl;
            return .VarUntypedDecl;
        } else {
            if (typed) return .DefDecl;
            return .DefUntypedDecl;
        }
    }

    fn tupleOrGroupingType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const lsquare = self.peekThenAdvance();

        if (self.matchThenAdvance(.Rsquare)) {
            try self.addIR(.TupleType, lsquare, 0);
            return;
        }

        try self.typeRule();

        const isTuple = if (self.match(.Comma)) true else false;

        while (self.consumeCommaAndNotMatch(.Rsquare)) {
            try self.typeRule();
        }
        try self.expectAdvance(.Rsquare, "Expecting a right square bracket for closing type");

        if (isTuple) {
            try self.addIR(.TupleType, lsquare, self.currentIrIndex() - end_index);
        }
    }

    fn funParamType(self: *Parser) ParseError!void {
        try self.expectAdvance(.Lparen, "Expecting a parentheses for function type parameters");
        if (self.matchThenAdvance(.Rparen)) return;

        var variadic: ?luv.Token = null;

        while (true) : (if (!self.consumeCommaAndNotMatch(.Rparen) or variadic != null) break) {
            if (self.match(.DotDot)) {
                variadic = self.peekThenAdvance();
                const variadic_end_index = self.currentIrIndex();

                try self.typeRule();

                try self.addIR(.RestPrefix, variadic.?, self.currentIrIndex() - variadic_end_index);
            } else {
                try self.typeRule();
            }
        }

        if (variadic != null and !self.match(.Rparen)) {
            if (self.errors) |*err| try err.errorFunVariadicUnclosed(
                self.curr().pos,
                variadic.?.pos,
            );
            return error.BadSyntax;
        }

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing function type parameters");
    }

    fn funType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fun = self.peekThenAdvance();

        try self.funParamType();

        try self.typeRule();

        try self.addIR(.FunType, fun, self.currentIrIndex() - end_index);
    }

    fn symType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const sym = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for sym type");

        try self.expect(.Identifier, "Expecting atleast a single identifier for sym type");
        while (true) : (if (!self.match(.Identifier)) break) {
            try self.addIR(.Identifier, self.peekThenAdvance(), 0);
            _ = self.matchThenAdvance(.Comma);
        }

        try self.expectAdvance(.Rbrace, "Expecting a right curly bracket for closing sym type");

        try self.addIR(.SymType, sym, self.currentIrIndex() - end_index);
    }

    fn methodType(self: *Parser) ParseError!void {
        const method_end_index = self.currentIrIndex();
        const tok = self.curr();

        try self.expectAdvance(.Lparen, "Expecting a parentheses for function type parameters");
        if (self.matchThenAdvance(.Rparen)) return;

        var variadic: ?luv.Token = null;

        while (true) : (if (!self.consumeCommaAndNotMatch(.Rparen) or variadic != null) break) {
            if (self.match(.DotDot)) {
                variadic = self.peekThenAdvance();
                const variadic_end_index = self.currentIrIndex();

                if (self.match(.Own)) {
                    try self.addIR(.BuiltinType, self.peekThenAdvance(), 0);
                } else {
                    try self.typeRule();
                }

                try self.addIR(.RestPrefix, variadic.?, self.currentIrIndex() - variadic_end_index);
            } else {
                if (self.match(.Own)) {
                    try self.addIR(.BuiltinType, self.peekThenAdvance(), 0);
                } else {
                    try self.typeRule();
                }
            }
        }

        if (variadic != null and !self.match(.Rparen)) {
            if (self.errors) |*err| try err.errorFunVariadicUnclosed(
                self.curr().pos,
                variadic.?.pos,
            );
            return error.BadSyntax;
        }

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing function parameters");

        if (self.match(.Own)) {
            try self.addIR(.BuiltinType, self.peekThenAdvance(), 0);
        } else {
            try self.typeRule();
        }

        try self.addIR(.FitMethodType, tok, self.currentIrIndex() - method_end_index);
    }

    fn fitType(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fit = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for fit type specification");

        while (!self.matchThenAdvance(.Rbrace)) {
            const def = if (self.match(.Def)) self.peekThenAdvance() else null;

            try self.expect(.Identifier, "Expecting Identifier in a fit type");

            const id_end_index = self.currentIrIndex();
            const id = self.peekThenAdvance();

            if (self.match(.Lparen)) {
                try self.methodType();
            } else {
                try self.typeRule();
            }

            try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - id_end_index);

            if (def) |tok| {
                try self.addIR(.DefDecorator, tok, self.currentIrIndex() - id_end_index);
            }
            _ = self.matchThenAdvance(.Comma);
        }

        try self.addIR(.FitType, fit, self.currentIrIndex() - end_index);
    }

    fn typeBase(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Identifier => try self.namespacedIdentifier(),
            .Lsquare => return self.tupleOrGroupingType(),
            .Int, .Str, .Bol, .Flo, .Nil, .Any => {
                self.advance();
                try self.addIR(.BuiltinType, tok, 0);
            },
            .Fun => return self.funType(),
            .Sym => return self.symType(),
            .Fit => return self.fitType(),
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "Type");
                return error.BadSyntax;
            },
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

        if (self.match(.Bang)) {
            const tok = self.peekThenAdvance();

            try self.typePostFix();

            try self.addIR(.ResultType, tok, self.currentIrIndex() - end_index);
        }
    }

    fn genericFulfillment(self: *Parser, end_index: usize) ParseError!void {
        const lsquare = self.peekThenAdvance();

        if (self.match(.Rsquare)) {
            if (self.errors) |*err| try err.errorEmptyGeneric(lsquare.pos);
            return error.BadSyntax;
        }

        try self.typeRule();

        while (self.consumeCommaAndNotMatch(.Rsquare)) {
            try self.typeRule();
        }

        try self.expectAdvance(.Rsquare, "Expecting a right square bracket for closing generic fulfillment");

        try self.addIR(.GenericFulfillPostFix, lsquare, self.currentIrIndex() - end_index);
    }

    fn tupleExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const lparen = self.peekThenAdvance();

        if (self.matchThenAdvance(.Rparen)) {
            try self.addIR(.TupleExpr, lparen, 0);
            return;
        }

        try self.expression();

        while (self.consumeCommaAndNotMatch(.Rparen)) {
            try self.expression();
        }

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing tuple expression");

        try self.addIR(.TupleExpr, lparen, self.currentIrIndex() - end_index);
    }

    fn tupleOrGroupingExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const lparen = self.peekThenAdvance();
        var isTuple = false;

        if (self.matchThenAdvance(.Rparen)) {
            try self.addIR(.TupleExpr, lparen, 0);
            return;
        }

        try self.expression();

        if (self.match(.Comma)) {
            isTuple = true;
        }

        while (self.consumeCommaAndNotMatch(.Rparen)) {
            try self.expression();
        }
        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing expression");

        if (isTuple) {
            try self.addIR(.TupleExpr, lparen, self.currentIrIndex() - end_index);
        }
    }

    fn objExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const lbrace = self.peekThenAdvance();

        while (!self.matchThenAdvance(.Rbrace)) {
            const attribute_end_index = self.currentIrIndex();

            if (self.match(.DotDot)) {
                const tok = self.peekThenAdvance();

                try self.expression();
                try self.addIR(.RestPrefix, tok, self.currentIrIndex() - attribute_end_index);

                _ = self.matchThenAdvance(.Comma);
                continue;
            }

            const def = if (self.match(.Def)) self.peekThenAdvance() else null;

            try self.expect(.Identifier, "Expecting an Identifier in object expression");
            try self.addIR(.Identifier, self.peekThenAdvance(), 0);

            try self.expect(.Equal, "Expecting a '=' after identifier");
            const eql = self.peekThenAdvance();

            try self.expression();

            try self.addIR(.Assignment, eql, self.currentIrIndex() - attribute_end_index);

            if (def) |tok| try self.addIR(.DefDecorator, tok, self.currentIrIndex() - attribute_end_index);

            _ = self.matchThenAdvance(.Comma);
        }

        try self.addIR(.ObjExpr, lbrace, self.currentIrIndex() - end_index);
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
            .Lparen => try self.tupleOrGroupingExpr(),
            .Lbrace => try self.objExpr(),
            .True, .False => {
                self.advance();
                try self.addIR(.BooleanLiteral, tok, 0);
            },
            .Int, .Str, .Bol, .Flo, .Nil => {
                self.advance();
                try self.addIR(.BuiltinType, tok, 0);
            },
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "Expression");
                return error.BadSyntax;
            },
        }
    }

    fn dotPostFix(self: *Parser, end_index: usize) ParseError!void {
        const dot = self.peekThenAdvance();

        const tok = self.curr();
        switch (tok.tt) {
            .Identifier => try self.addIR(.Identifier, self.peekThenAdvance(), 0),
            .IntLiteral => try self.addIR(.IntLiteral, self.peekThenAdvance(), 0),
            .Lparen => try self.tupleExpr(),
            .Lbrace => try self.objExpr(),
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "DotPostFix");
                return error.BadSyntax;
            },
        }

        try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);
    }

    fn callPostFix(self: *Parser, end_index: usize) ParseError!void {
        const tok = self.peekThenAdvance();
        if (self.matchThenAdvance(.Rparen)) {
            try self.addIR(.CallPostFix, tok, self.currentIrIndex() - end_index);
            return;
        }

        while (true) : (if (!self.consumeCommaAndNotMatch(.Rparen)) break) {
            if (self.match(.DotDot)) {
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
        if (self.matchAny(&[_]luv.TokenType{ .Not, .Minus })) {
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

        while (self.matchAny(&[_]luv.TokenType{ .Asterisk, .Solidus, .Modulus })) {
            const tok = self.peekThenAdvance();

            try self.unaryExpr();

            try self.addIR(.Arithmetic, tok, self.currentIrIndex() - end_index);
        }
    }

    fn termExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.factorExpr();

        while (self.matchAny(&[_]luv.TokenType{ .Plus, .Minus })) {
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

        if (self.matchAny(relationalTokens)) {
            const tok = self.peekThenAdvance();

            try self.termExpr();

            try self.addIR(.Relational, tok, self.currentIrIndex() - end_index);
        }

        if (self.matchAny(relationalTokens)) {
            const tok = self.peekThenAdvance();

            if (self.errors) |*err| try err.errorIllegalChainUseGrouping(
                "relational expression",
                tok.pos,
            );

            return error.BadSyntax;
        }
    }

    fn andExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.relationalExpr();

        while (self.match(.And)) {
            const tok = self.peekThenAdvance();

            try self.relationalExpr();

            try self.addIR(.LogicBinary, tok, self.currentIrIndex() - end_index);
        }
    }

    fn orExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.andExpr();

        while (self.match(.Or)) {
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

        if (self.matchAny(assignmentTokens)) {
            const tok = self.peekThenAdvance();

            try self.expression();

            try self.addIR(.Assignment, tok, self.currentIrIndex() - end_index);
        }
    }

    fn funParameters(self: *Parser) ParseError!void {
        try self.expectAdvance(.Lparen, "Expecting a parentheses for function parameter");
        if (self.matchThenAdvance(.Rparen)) return;

        var variadic: ?luv.Token = null;

        while (true) : (if (!self.consumeCommaAndNotMatch(.Rparen) or variadic != null) break) {
            if (self.match(.DotDot)) {
                variadic = self.peekThenAdvance();
                const variadic_end_index = self.currentIrIndex();

                try self.expect(.Identifier, "Expecting identifier after variadic in function parameter");
                const id = self.peekThenAdvance();

                try self.typeRule();

                try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - variadic_end_index);

                try self.addIR(.RestPrefix, variadic.?, self.currentIrIndex() - variadic_end_index);
            } else {
                const id_end_index = self.currentIrIndex();
                try self.expect(.Identifier, "Expecting identifier-type pair in function parameter");
                const id = self.peekThenAdvance();

                try self.typeRule();

                try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - id_end_index);
            }
        }

        if (variadic != null and !self.match(.Rparen)) {
            if (self.errors) |*err| try err.errorFunVariadicUnclosed(
                self.curr().pos,
                variadic.?.pos,
            );
            return error.BadSyntax;
        }

        try self.expectAdvance(.Rparen, "Expecting a right parentheses for closing function parameters");
    }

    fn funExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fun = self.peekThenAdvance();

        if (self.match(.Lsquare)) {
            try self.genericDeclaration();
        }

        try self.funParameters();

        if (!self.match(.Lbrace)) {
            try self.typeRule();
        }

        try self.expect(.Lbrace, "Expecting a block in function expression");
        try self.blockStmt();

        try self.addIR(.FunExpr, fun, self.currentIrIndex() - end_index);
    }

    fn ifVarGuard(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const tok = self.peekThenAdvance();

        try self.destructurePattern();

        const isTyped = if (self.match(.Of)) blk: {
            const of = self.peekThenAdvance();

            try self.expect(.Identifier, "Expecting identifier after 'of'");
            try self.addIR(.Identifier, self.peekThenAdvance(), 0);

            try self.addIR(.OfPrefix, of, 1);
            break :blk true;
        } else if (!self.match(.Equal)) blk: {
            try self.typeRule();
            break :blk true;
        } else false;

        try self.expectAdvance(.Equal, "Expecting '=' sign for if variable definition");

        try self.relationalExpr();

        try self.addIR(vardefIRChooseFrom(tok.tt, isTyped), tok, self.currentIrIndex() - end_index);

        if (!self.matchAny(&.{ .Lbrace, .Arrow })) {
            try self.expectAdvance(.And, "Expecting 'and' for bridging if variable and if condition");
        }
    }

    fn arrowOrBlock(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Arrow => {
                const end_index = self.currentIrIndex();
                self.advance();
                try self.expression();
                try self.addIR(.YieldStmt, tok, self.currentIrIndex() - end_index);
            },
            .Lbrace => try self.blockStmt(),
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "Arrow or BlockStmt");
                return error.BadSyntax;
            },
        }
    }

    fn ifExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const if_tok = self.peekThenAdvance();

        var hasGuard = false;
        while (self.matchAny(&.{ .Var, .Def })) {
            try self.ifVarGuard();
            hasGuard = true;
        }

        if (!hasGuard and self.matchAny(&.{ .Lbrace, .Arrow })) {
            if (self.errors) |*err| try err.errorExpectedSomeRule(
                self.curr().pos,
                "if condition",
            );
            return error.BadSyntax;
        }

        if (!self.matchAny(&.{ .Lbrace, .Arrow })) try self.expression();

        try self.arrowOrBlock();

        if (self.match(.Elif)) {
            try self.ifExpr();
        }

        if (self.match(.Else)) {
            const else_end_index = self.currentIrIndex();
            const else_tok = self.peekThenAdvance();
            try self.arrowOrBlock();

            try self.addIR(.IfExpr, else_tok, self.currentIrIndex() - else_end_index);
        }

        try self.addIR(.IfExpr, if_tok, self.currentIrIndex() - end_index);
    }

    fn forExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const for_tok = self.peekThenAdvance();

        const tok = self.curr();
        switch (tok.tt) {
            .Var, .Def => {
                self.advance();
                try self.destructurePattern();

                const typed = if (!self.match(.In)) blk: {
                    try self.typeRule();
                    break :blk true;
                } else false;

                try self.expectAdvance(.In, "Expecting 'in' after 'for' variable definition");

                try self.expression();

                try self.addIR(vardefIRChooseFrom(tok.tt, typed), tok, self.currentIrIndex() - end_index);
            },
            else => try self.expression(),
            .Lbrace => {},
        }

        try self.expect(.Lbrace, "Expecting block statement inside 'for' expression");
        try self.blockStmt();

        try self.addIR(.ForExpr, for_tok, self.currentIrIndex() - end_index);
    }

    fn matchCaseArms(self: *Parser) ParseError!void {
        while (self.match(.Case)) {
            const end_index = self.currentIrIndex();
            const case_tok = self.peekThenAdvance();

            try self.expression();

            while (self.matchThenAdvance(.Comma) and !self.matchAny(&.{ .Lbrace, .Arrow })) {
                try self.expression();
            }

            try self.arrowOrBlock();

            _ = self.matchThenAdvance(.Comma);

            try self.addIR(.MatchCaseArm, case_tok, self.currentIrIndex() - end_index);
        }
    }

    fn matchTagArms(self: *Parser) ParseError!void {
        while (self.match(.Identifier)) {
            const end_index = self.currentIrIndex();
            const id = self.curr();

            try self.destructurePattern();

            // A tag arm can start with just its own tag name which will just emit one ID
            const of_tok = if (self.currentIrIndex() != end_index + 1 or self.match(.Of)) blk: {
                try self.expect(.Of, "Expecting 'of' keyword for matching a tag");
                const tok = self.peekThenAdvance();

                try self.addIR(.Identifier, self.peekThenAdvance(), 0);

                try self.addIR(.OfPrefix, tok, 1);

                break :blk tok;
            } else null;

            try self.arrowOrBlock();

            _ = self.matchThenAdvance(.Comma);

            try self.addIR(.MatchTagArm, if (of_tok) |tok| tok else id, self.currentIrIndex() - end_index);
        }
    }

    fn matchExpr(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const match_tok = self.peekThenAdvance();

        try self.expression();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for match expression");

        const tok = self.curr();
        switch (tok.tt) {
            .Case => try self.matchCaseArms(),
            .Identifier => try self.matchTagArms(),
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "Case or Tag matching");
                return error.BadSyntax;
            },
        }

        if (self.matchThenAdvance(.Else)) {
            try self.arrowOrBlock();
        }

        try self.expectAdvance(.Rbrace, "Expecting a right closing curly brackets for match expression");

        try self.addIR(.MatchExpr, match_tok, self.currentIrIndex() - end_index);
    }

    fn expression(self: *Parser) ParseError!void {
        switch (self.curr().tt) {
            .Match => try self.matchExpr(),
            .For => try self.forExpr(),
            .If => try self.ifExpr(),
            .Fun => try self.funExpr(),
            else => try self.assignmentExpr(),
        }
    }

    fn namespacedIdentifier(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.addIR(.Identifier, self.peekThenAdvance(), 0);

        while (self.match(.Dot)) {
            const dot = self.peekThenAdvance();

            try self.expect(.Identifier, "Expecting identifier after dot '.' for namespaced identifier");
            const access = self.peekThenAdvance();

            try self.addIR(.Identifier, access, 0);

            try self.addIR(.DotAccess, dot, self.currentIrIndex() - end_index);
        }
    }

    fn topLevelDef(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const def = self.peekThenAdvance();

        // TODO def test
        const caret = if (self.match(.Caret)) self.peekThenAdvance() else null;

        try self.expect(.Identifier, "Expecting identifier after 'def' for top level def statement");
        try self.namespacedIdentifier();

        try self.inferOptionalView(end_index);

        if (self.match(.Comma)) {
            if (self.errors) |*err| try err.errorTupleDestructure(self.curr().pos, "Top level def");
            return error.BadSyntax;
        }

        var isTyped = false;
        if (!self.match(.Equal)) {
            try self.typeRule();
            isTyped = true;
        }

        try self.expectAdvance(.Equal, "Expecting '=' after an identifier in def declaration");

        try self.expression();

        try self.addIR(if (isTyped) .DefDecl else .DefUntypedDecl, def, self.currentIrIndex() - end_index);

        if (caret) |tok| try self.addIR(.ExportDecorator, tok, self.currentIrIndex() - end_index);
    }

    fn genericDeclaration(self: *Parser) ParseError!void {
        const generic_end_index = self.currentIrIndex();
        const generic_token = self.peekThenAdvance();
        try self.expect(.Identifier, "Expecting atleast a single type bound in a generic declaration");

        while (true) : (if (!self.consumeCommaAndNotMatch(.Rsquare)) break) {
            const tyid_end_index = self.currentIrIndex();
            const tyid = self.peekThenAdvance();
            try self.typeRule();

            try self.addIR(.TypedIdentifier, tyid, self.currentIrIndex() - tyid_end_index);
        }

        try self.expectAdvance(.Rsquare, "Expecting a right curly bracket for closing generic declaration");

        try self.addIR(.GenericDeclaration, generic_token, self.currentIrIndex() - generic_end_index);
    }

    fn nomType(self: *Parser) ParseError!void {
        const nom = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for nom type");
        const end_index = self.currentIrIndex();

        while (!self.matchThenAdvance(.Rbrace)) {
            const def = if (self.match(.Def)) self.peekThenAdvance() else null;
            const caret = if (self.match(.Caret)) self.peekThenAdvance() else null;

            try self.expect(.Identifier, "Expecting an Identifier in nom type");
            const id_end_index = self.currentIrIndex();
            const id = self.peekThenAdvance();

            try self.typeRule();

            try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - id_end_index);

            if (def) |tok| try self.addIR(.DefDecorator, tok, self.currentIrIndex() - id_end_index);
            if (caret) |tok| try self.addIR(.ExportDecorator, tok, self.currentIrIndex() - id_end_index);

            _ = self.matchThenAdvance(.Comma);
        }

        try self.addIR(.NomType, nom, self.currentIrIndex() - end_index);
    }

    fn tagType(self: *Parser) ParseError!void {
        const tag = self.peekThenAdvance();

        try self.expectAdvance(.Lbrace, "Expecting curly brackets for tag type");

        const end_index = self.currentIrIndex();

        while (!self.matchThenAdvance(.Rbrace)) {
            const id_end_index = self.currentIrIndex();
            try self.expect(.Identifier, "Expecting Identifier in tag type");
            const id = self.peekThenAdvance();
            try self.typeRule();

            try self.addIR(.TypedIdentifier, id, self.currentIrIndex() - id_end_index);
            _ = self.matchThenAdvance(.Comma);
        }

        try self.addIR(.TagType, tag, self.currentIrIndex() - end_index);
    }

    fn typeDeclRule(self: *Parser) ParseError!void {
        switch (self.curr().tt) {
            .Nom => try self.nomType(),
            .Tag => try self.tagType(),
            else => try self.typeRule(),
        }
    }

    fn typeDecl(self: *Parser) ParseError!void {
        const end_index = self.result.items.len;
        const typ_tok = self.peekThenAdvance();

        const caret = if (self.match(.Caret)) self.peekThenAdvance() else null;

        try self.expect(.Identifier, "Expecting identifier after 'typ' for type declaration");
        try self.namespacedIdentifier();

        if (self.match(.Lsquare)) {
            try self.genericDeclaration();
        }

        try self.typeDeclRule();

        try self.addIR(.TypDecl, typ_tok, self.result.items.len - end_index);

        if (caret) |tok| try self.addIR(.ExportDecorator, tok, self.currentIrIndex() - end_index);
    }

    fn topLevelFun(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const fun = self.peekThenAdvance();

        // TODO fun test
        const caret = if (self.match(.Caret)) self.peekThenAdvance() else null;

        try self.expect(.Identifier, "Expecting an identifier for top level function declaration");
        try self.namespacedIdentifier();

        const fun_end_index = self.currentIrIndex();

        if (self.match(.Lsquare)) {
            try self.genericDeclaration();
        }

        try self.funParameters();

        if (!self.match(.Lbrace)) {
            try self.typeRule();
        }

        try self.expect(.Lbrace, "Expecting a block in function expression");
        try self.blockStmt();

        try self.addIR(.FunExpr, fun, self.currentIrIndex() - fun_end_index);

        try self.addIR(.DefUntypedDecl, fun, self.currentIrIndex() - end_index);

        if (caret) |tok| try self.addIR(.ExportDecorator, tok, self.currentIrIndex() - end_index);
    }

    fn inferOptionalView(self: *Parser, end_index: usize) ParseError!void {
        switch (self.curr().tt) {
            .QuestionMark => try self.addIR(.OptionalType, self.peekThenAdvance(), self.currentIrIndex() - end_index),
            .Ampersand => try self.addIR(.ViewType, self.peekThenAdvance(), self.currentIrIndex() - end_index),
            else => {},
        }
    }

    fn destructurePattern(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        try self.addIR(.Identifier, self.peekThenAdvance(), 0);

        try self.inferOptionalView(end_index);

        const tupleDestructure = if (self.match(.Comma)) self.curr() else null;

        while (self.matchThenAdvance(.Comma)) {
            try self.expect(.Identifier, "Expecting identifier in tuple destructure");
            try self.addIR(.Identifier, self.peekThenAdvance(), 0);

            try self.inferOptionalView(end_index);
        }

        if (tupleDestructure) |tup| try self.addIR(.TupleType, tup, self.currentIrIndex() - end_index);
    }

    fn varStmt(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const tok = self.peekThenAdvance();

        try self.expect(.Identifier, "Expecting identifier after 'var'");
        try self.destructurePattern();

        var isTyped = false;
        if (!self.match(.Equal)) {
            try self.typeRule();
            isTyped = true;
        }

        try self.expectAdvance(.Equal, "Expecting '=' after an identifier in var declaration");

        try self.expression();

        try self.addIR(if (isTyped) .VarDecl else .VarUntypedDecl, tok, self.currentIrIndex() - end_index);
    }

    fn defStmt(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const tok = self.peekThenAdvance();

        try self.expect(.Identifier, "Expecting identifier after 'def'");
        try self.destructurePattern();

        var isTyped = false;
        if (!self.match(.Equal)) {
            try self.typeRule();
            isTyped = true;
        }

        try self.expectAdvance(.Equal, "Expecting '=' after an identifier in def declaration");

        try self.expression();

        try self.addIR(if (isTyped) .DefDecl else .DefUntypedDecl, tok, self.currentIrIndex() - end_index);
    }

    fn blockStmt(self: *Parser) ParseError!void {
        const end_index = self.currentIrIndex();
        const lbrace = self.peekThenAdvance();

        while (!self.match(.Rbrace)) {
            try self.statement();
        }
        self.advance(); // advancing the Rbrace

        try self.addIR(.BlockStmt, lbrace, self.currentIrIndex() - end_index);
    }

    fn resultStmt(self: *Parser) ParseError!void {
        const tok = self.peekThenAdvance();

        if (self.matchAny(&[_]luv.TokenType{ .Rbrace, .Semicolon })) return try self.addIR(
            switch (tok.tt) {
                .Return => .ReturnStmt,
                .Break => .BreakStmt,
                .Yield => .YieldStmt,
                else => unreachable,
            },
            tok,
            0,
        );

        const end_index = self.currentIrIndex();
        try self.expression();

        if (!self.match(.Rbrace)) {
            if (self.errors) |*err| try err.errorUnreachableReturn(tok.pos, self.curr().pos);
            return error.BadSyntax;
        }

        try self.addIR(
            switch (tok.tt) {
                .Return => .ReturnStmt,
                .Break => .BreakStmt,
                .Yield => .YieldStmt,
                else => unreachable,
            },
            tok,
            self.currentIrIndex() - end_index,
        );
    }

    fn statement(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Def => try self.defStmt(),
            .Var => try self.varStmt(),
            .Lbrace => try self.blockStmt(),
            .Return, .Break, .Yield => try self.resultStmt(),
            .Continue => try self.addIR(.ContinueStmt, tok, 0),
            else => try self.expression(),
        }
        _ = self.matchThenAdvance(.Semicolon);
    }

    fn topLevelStatement(self: *Parser) ParseError!void {
        const tok = self.curr();
        switch (tok.tt) {
            .Def => try self.topLevelDef(),
            .Typ => try self.typeDecl(),
            .Semicolon => if (self.errors) |*err| try err.warnRedundantToken(
                tok.pos,
                "Redundant semicolon on an empty statement",
            ),
            .Fun => try self.topLevelFun(),

            // TODO useStmt
            else => {
                if (self.errors) |*err| try err.errorExpectedSomeRule(tok.pos, "Top Level Statement");
                return error.BadSyntax;
            },
        }
        _ = self.matchThenAdvance(.Semicolon);
    }

    pub fn parse(
        self: *Parser,
        allocator: std.mem.Allocator,
        tokens: []const luv.Token,
    ) ParseError!std.ArrayList(luv.IR) {
        self.tokens = tokens;
        self.result = try .initCapacity(allocator, 32);
        errdefer self.result.deinit(self.allocator);
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
        errdefer self.result.deinit(self.allocator);
        self.allocator = allocator;

        try self.expression();

        return self.result;
    }

    pub fn parseStmt(
        self: *Parser,
        allocator: std.mem.Allocator,
        tokens: []const luv.Token,
    ) ParseError!std.ArrayList(luv.IR) {
        self.tokens = tokens;
        self.result = try .initCapacity(allocator, 32);
        errdefer self.result.deinit(self.allocator);
        self.allocator = allocator;

        try self.statement();

        return self.result;
    }
};
