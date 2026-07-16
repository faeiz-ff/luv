const std = @import("std");
const luv = @import("luv");

pub const LexError = error{
    BadSyntax,
    InternalErr,
    WriteFailed,
    OutOfMemory,
};

/// Luv Programming Language Lexer
/// Initialize with .init or .initWithErr
pub const Lexer = struct {
    char_index: usize,
    code: []const u8,
    pos: luv.Position,
    errors: ?luv.ErrorReport,

    pub const empty: Lexer = .{
        .char_index = 0,
        .code = undefined,
        .pos = .{
            .x = 0,
            .y = 0,
        },
        .errors = null,
    };

    /// Assign custom error writer target to lexer
    pub fn assignErr(self: *Lexer, errWriter: *std.Io.Writer) void {
        self.errors = .init(errWriter);
    }

    /// Peek a letter, 0 for reading the current char, returns null if out of range
    fn peek(self: *Lexer, num: comptime_int) ?u8 {
        if (self.char_index + num < self.code.len) {
            return self.code.ptr[self.char_index + num];
        } else {
            return null;
        }
    }

    fn isAlpha(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
    }

    fn isNumeric(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    fn isAlphaNumeric(ch: u8) bool {
        return isAlpha(ch) or isNumeric(ch) or ch == '_';
    }

    fn isHex(ch: u8) bool {
        return isNumeric(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
    }

    fn isOct(ch: u8) bool {
        return ch >= '0' and ch <= '7';
    }

    fn isBin(ch: u8) bool {
        return ch == '0' or ch == '1';
    }

    fn isWhitespace(ch: u8) bool {
        return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r';
    }

    /// Returns an EOF token, should only be called last
    fn makeEof(self: *Lexer) luv.Token {
        self.char_index += 1;
        return .{
            .lexeme = "eof",
            .tt = .Eof,
            .pos = .{
                .x = self.pos.x,
                .y = self.pos.y,
            },
        };
    }

    /// Returns a token, and add lexeme length into current x_pos
    fn makeToken(self: *Lexer, lexeme: []const u8, tt: luv.TokenType) luv.Token {
        const last_x_pos = self.pos.x;
        self.pos.x += @intCast(lexeme.len);
        return .{
            .lexeme = lexeme,
            .tt = tt,
            .pos = .{
                .x = last_x_pos,
                .y = @intCast(self.pos.y),
            },
        };
    }

    /// Returns a token with double_tt Type if peek_ch is correct, default_tt otherwise.
    fn doubleCharToken(
        self: *Lexer,
        default_tt: luv.TokenType,
        peek_ch: u8,
        double_tt: luv.TokenType,
    ) luv.Token {
        const ch = self.peek(1);
        if (ch != null and ch.? == peek_ch) {
            self.char_index += 2;
            return self.makeToken(self.code[self.char_index - 2 .. self.char_index], double_tt);
        } else {
            self.char_index += 1;
            return self.makeToken(self.code[self.char_index - 1 .. self.char_index], default_tt);
        }
    }

    /// Returns a token with tt type
    fn singleCharToken(self: *Lexer, tt: luv.TokenType) luv.Token {
        self.char_index += 1;
        return self.makeToken(self.code[self.char_index - 1 .. self.char_index], tt);
    }

    /// !! Assumes a non null read at self.char_index
    fn primitiveToken(self: *Lexer) LexError!luv.Token {
        const ch = self.peek(0).?;
        return switch (ch) {
            '*' => self.doubleCharToken(.Asterisk, '=', .AsteriskEqual),
            '/' => self.doubleCharToken(.Solidus, '=', .SolidusEqual),
            '+' => self.doubleCharToken(.Plus, '=', .PlusEqual),
            '%' => self.doubleCharToken(.Modulus, '=', .ModulusEqual),
            '<' => self.doubleCharToken(.Less, '=', .LessEqual),
            '>' => self.doubleCharToken(.Greater, '=', .GreaterEqual),
            '=' => self.doubleCharToken(.Equal, '=', .EqualEqual),
            '!' => self.doubleCharToken(.Bang, '=', .BangEqual),
            '.' => self.doubleCharToken(.Dot, '.', .DotDot),

            '&' => self.singleCharToken(.Ampersand),
            '{' => self.singleCharToken(.Lbrace),
            '}' => self.singleCharToken(.Rbrace),
            '(' => self.singleCharToken(.Lparen),
            ')' => self.singleCharToken(.Rparen),
            '[' => self.singleCharToken(.Lsquare),
            ']' => self.singleCharToken(.Rsquare),
            ',' => self.singleCharToken(.Comma),
            ';' => self.singleCharToken(.Semicolon),
            '?' => self.singleCharToken(.QuestionMark),
            '^' => self.singleCharToken(.Caret),

            '-' => {
                const peek_ch = self.peek(1) orelse return self.singleCharToken(.Minus);
                if (peek_ch == '>') {
                    self.char_index += 2;
                    return self.makeToken(
                        self.code[self.char_index - 2 .. self.char_index],
                        .Arrow,
                    );
                } else if (peek_ch == '=') {
                    self.char_index += 2;
                    return self.makeToken(
                        self.code[self.char_index - 2 .. self.char_index],
                        .MinusEqual,
                    );
                } else {
                    self.char_index += 1;
                    return self.makeToken(self.code[self.char_index - 1 .. self.char_index], .Minus);
                }
            },
            else => return self.reportErrorUnknownOperator(),
        };
    }

    fn skipWhitespace(self: *Lexer) void {
        var ch = self.peek(0) orelse return;
        while (isWhitespace(ch)) {
            self.char_index += 1;
            self.pos.x += 1;
            if (ch == '\n') {
                self.pos.y += 1;
                self.pos.x = 0;
            }
            ch = self.peek(0) orelse return;
        }
    }

    /// !! Assumes a '#' is read at self.char_index
    fn comment(self: *Lexer) void {
        self.char_index += 1;
        var ch = self.peek(0) orelse return;
        while (ch != '\n') {
            self.char_index += 1;
            ch = self.peek(0) orelse return;
        }
    }

    fn matchKeyword(self: *Lexer, start: usize, end: usize, comptime tt: luv.TokenType) ?luv.TokenType {
        if (std.mem.order(u8, self.code[start + 1 .. end], @tagName(tt)[1..]) == .eq) {
            return tt;
        } else {
            return null;
        }
    }

    fn matchKeywords(self: *Lexer, start: usize, end: usize, comptime tts: []const luv.TokenType) ?luv.TokenType {
        inline for (tts) |tt| {
            if (std.mem.order(u8, self.code[start + 1 .. end], @tagName(tt)[1..]) == .eq) return tt;
        }
        return null;
    }

    /// Returns a Keyword TokenType !! Assumes start and end as valid slice index of self.code
    fn keywordType(self: *Lexer, start: usize, end: usize) ?luv.TokenType {
        return switch (end - start) {
            2 => switch (self.code[start]) {
                'i' => self.matchKeywords(start, end, &[_]luv.TokenType{ .If, .In }),
                'o' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Of, .Or }),
                else => null,
            },
            3 => switch (self.code[start]) {
                'a' => self.matchKeywords(start, end, &[_]luv.TokenType{ .And, .Any }),
                'b' => self.matchKeyword(start, end, .Bol),
                'd' => self.matchKeyword(start, end, .Def),
                'f' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Fun, .For, .Fit, .Flo }),
                'i' => self.matchKeyword(start, end, .Int),
                'n' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Nom, .Not, .Nil }),
                'O' => self.matchKeyword(start, end, .Own),
                's' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Str, .Sym }),
                't' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Tag, .Typ }),
                'u' => self.matchKeyword(start, end, .Use),
                'v' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Var, .Vec }),
                else => null,
            },
            4 => switch (self.code[start]) {
                'c' => self.matchKeyword(start, end, .Case),
                'e' => self.matchKeywords(start, end, &[_]luv.TokenType{ .Elif, .Else }),
                't' => self.matchKeywords(start, end, &[_]luv.TokenType{ .True, .Test }),
                else => null,
            },
            5 => switch (self.code[start]) {
                'b' => self.matchKeyword(start, end, .Break),
                'f' => self.matchKeyword(start, end, .False),
                'm' => self.matchKeyword(start, end, .Match),
                'y' => self.matchKeyword(start, end, .Yield),
                else => null,
            },
            6 => switch (self.code[start]) {
                'r' => self.matchKeyword(start, end, .Return),
                else => null,
            },
            8 => switch (self.code[start]) {
                'c' => self.matchKeyword(start, end, .Continue),
                else => null,
            },
            else => null,
        };
    }

    /// Returns either an .Identifier or Keywords !! Assumes an Alphabetic char is read at self.char_index
    fn identifierOrKeyword(self: *Lexer) luv.Token {
        const start = self.char_index;
        var ch = self.peek(0).?;
        while (isAlphaNumeric(ch)) {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        const tt: luv.TokenType = self.keywordType(start, self.char_index) orelse .Identifier;

        return self.makeToken(self.code[start..self.char_index], tt);
    }

    /// Returns either a .Float or .Int luv token !! Assumes a valid number is read at self.char_index
    fn number(self: *Lexer) LexError!luv.Token {
        var ch = self.peek(0).?;
        if (ch == '0') {
            const peek_ch = self.peek(1);
            if (peek_ch != null) switch (peek_ch.?) {
                'b' => return self.binNumber(),
                'o' => return self.octNumber(),
                'x' => return self.hexNumber(),
                else => {},
            };
        }
        const start = self.char_index;
        var isFloat = false;
        var isExp = false;
        while (isNumeric(ch) or ch == '_') {
            self.char_index += 1;

            ch = self.peek(0) orelse break;
            if (!isFloat and ch == '.') {
                isFloat = true;
                self.char_index += 1;
                ch = self.peek(0) orelse break;
                if (!isNumeric(ch)) return self.reportErrorUnexpected("Numeric Value");
            } else if (!isExp and (ch == 'e' or ch == 'E')) {
                isFloat = true;
                isExp = true;
                self.char_index += 1;
                ch = self.peek(0) orelse break;
                if (ch == '-') {
                    self.char_index += 1;
                    ch = self.peek(0) orelse break;
                }
                if (!isNumeric(ch)) return self.reportErrorUnexpected("Numeric Value");
            }
        }

        return self.makeToken(self.code[start..self.char_index], if (isFloat) .FloatLiteral else .IntLiteral);
    }

    /// Returns an binary .Int luv token !! Assumes '0b' is read at self.char_index
    fn binNumber(self: *Lexer) LexError!luv.Token {
        self.char_index += 2;
        const start = self.char_index;
        var ch = self.peek(0) orelse return self.reportErrorUnexpected("Binary Number");
        while (isBin(ch) or ch == '_') {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        return self.makeToken(self.code[start..self.char_index], .IntLiteral);
    }

    /// Returns an hexadecimal .Int luv token !! Assumes '0x' is read at self.char_index
    fn hexNumber(self: *Lexer) LexError!luv.Token {
        self.char_index += 2;
        const start = self.char_index;
        var ch = self.peek(0) orelse return self.reportErrorUnexpected("Hexadecimal Number");
        while (isHex(ch) or ch == '_') {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        return self.makeToken(self.code[start..self.char_index], .IntLiteral);
    }

    /// Returns an octal .Int luv token !! Assumes '0o' is read at self.char_index
    fn octNumber(self: *Lexer) LexError!luv.Token {
        self.char_index += 2;
        const start = self.char_index;
        var ch = self.peek(0) orelse return self.reportErrorUnexpected("Octal Number");
        while (isOct(ch) or ch == '_') {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        return self.makeToken(self.code[start..self.char_index], .IntLiteral);
    }

    /// !! Assumes '"' is read at self.char_index
    fn string(self: *Lexer) LexError!luv.Token {
        const start = self.char_index;
        self.char_index += 1;
        var ch = self.peek(0) orelse return self.reportErrorUnterminatedString();
        while (ch != '"') {
            self.char_index += 1;
            ch = self.peek(0) orelse return self.reportErrorUnterminatedString();
            if (ch == '\\') {
                // TODO: Find out how to parse escaped characters
                self.char_index += 2;
                ch = self.peek(0) orelse return self.reportErrorUnterminatedString();
            }

            if (ch == '\n') return self.reportErrorUnterminatedString();
        }

        // consume end string
        self.char_index += 1;

        return self.makeToken(self.code[start..self.char_index], .StringLiteral);
    }

    fn reportErrorUnterminatedString(self: *Lexer) LexError {
        if (self.errors) |*err| {
            err.report(.Err, "Unterminated String")
                .withLineMsg(self.code, self.pos, "this string is unterminated")
                .flush() catch return LexError.WriteFailed;
        }
        return LexError.BadSyntax;
    }

    fn reportErrorUnknownOperator(self: *Lexer) LexError {
        if (self.errors) |*err| {
            err.report(.Err, "Unknown Operator")
                .withLineMsg(self.code, self.pos, "this operator is unknown")
                .flush() catch return LexError.WriteFailed;
        }
        return LexError.BadSyntax;
    }

    fn reportErrorUnexpected(self: *Lexer, comptime expect: []const u8) LexError {
        if (self.errors) |*err| {
            err.report(.Err, "Unexpected Symbol")
                .withLineMsg(self.code, self.pos, "expecting " ++ expect)
                .flush() catch return LexError.WriteFailed;
        }
        return LexError.BadSyntax;
    }

    /// Returns a single token, from the current char index slicing self.code
    /// The tokens returned will have slices of the code  as the lexeme
    pub fn scanToken(self: *Lexer) LexError!luv.Token {
        errdefer {
            self.char_index += 1;
            self.pos.x += 1;
        }

        var ch: u8 = undefined;
        while (true) {
            self.skipWhitespace();
            ch = self.peek(0) orelse return self.makeEof();
            if (isAlpha(ch)) {
                return self.identifierOrKeyword();
            } else if (isNumeric(ch)) {
                return self.number();
            } else if (ch == '#') {
                self.comment();
                ch = self.peek(0) orelse return self.makeEof();
            } else if (ch == '"') {
                return self.string();
            } else {
                return self.primitiveToken();
            }
        }
        unreachable;
    }

    /// Tokenize the whole code, returns an allocated ArrayList using allocator
    /// The tokens returned will have slices of self.code as the lexeme
    pub fn lexAll(
        self: *Lexer,
        allocator: std.mem.Allocator,
        code: []const u8,
    ) LexError!std.ArrayList(luv.Token) {
        self.code = code;

        var tokens = try std.ArrayList(luv.Token).initCapacity(allocator, 64);
        errdefer tokens.deinit(allocator);

        while (self.char_index <= self.code.len) {
            const tok = self.scanToken() catch |err| switch (err) {
                error.BadSyntax => continue,
                else => return err,
            };
            try tokens.append(allocator, tok);
        }

        return tokens;
    }
};
