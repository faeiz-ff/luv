const std = @import("std");
const luv = @import("root.zig");

const ErrorReport = @import("error-report.zig").ErrorReport;

pub const LexError = error{
    BadSyntax,
    InternalErr,
};

pub const Lexer = struct {
    char_index: usize,
    code: []const u8,
    x_pos: usize,
    y_pos: usize,
    errors: ErrorReport,

    pub const empty = Lexer{
        .char_index = 0,
        .code = undefined,
        .x_pos = 0,
        .y_pos = 0,
        .errors = .empty,
    };

    pub fn init(code: []const u8) Lexer {
        return .{
            .char_index = 0,
            .code = code,
            .x_pos = 0,
            .y_pos = 0,
            .errors = .empty,
        };
    }

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

    fn makeEof(self: *Lexer) luv.Token {
        self.char_index += 1;
        return .{
            .lexeme = "eof",
            .tt = .Eof,
            .x_pos = self.x_pos,
            .y_pos = self.y_pos,
        };
    }

    fn makeToken(self: *Lexer, lexeme: []const u8, tt: luv.TokenType) luv.Token {
        const last_x_pos = self.x_pos;
        self.x_pos += lexeme.len;
        return .{
            .lexeme = lexeme,
            .tt = tt,
            .x_pos = last_x_pos,
            .y_pos = self.y_pos,
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
            self.x_pos += 1;
            if (ch == '\n') {
                self.y_pos += 1;
                self.x_pos = 0;
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

    fn strEq(s1: []const u8, s2: []const u8) bool {
        return std.mem.order(u8, s1, s2) == std.math.Order.eq;
    }

    /// Returns a Keyword TokenType !! Assumes start and end as valid slice index of self.code
    fn keywordType(self: *Lexer, start: usize, end: usize) ?luv.TokenType {
        switch (end - start) {
            2 => switch (self.code[start]) {
                'i' => switch (self.code[start + 1]) {
                    'f' => return .If,
                    'n' => return .In,
                    else => return null,
                },
                'o' => switch (self.code[start + 1]) {
                    'f' => return .Of,
                    'r' => return .Or,
                    else => return null,
                },
                else => return null,
            },
            3 => switch (self.code[start]) {
                'a' => {
                    if (strEq(self.code[start + 1 .. end], "nd")) return .And;
                    if (strEq(self.code[start + 1 .. end], "ny")) return .Any;
                    return null;
                },
                'b' => if (strEq(self.code[start + 1 .. end], "ol")) return .Bol else return null,
                'd' => if (strEq(self.code[start + 1 .. end], "ef")) return .Def else return null,
                'f' => {
                    if (strEq(self.code[start + 1 .. end], "un")) return .Fun;
                    if (strEq(self.code[start + 1 .. end], "or")) return .For;
                    if (strEq(self.code[start + 1 .. end], "it")) return .Fit;
                    if (strEq(self.code[start + 1 .. end], "lo")) return .Flo;
                    return null;
                },
                'i' => if (strEq(self.code[start + 1 .. end], "nt")) return .Int else return null,
                'n' => {
                    if (strEq(self.code[start + 1 .. end], "om")) return .Nom;
                    if (strEq(self.code[start + 1 .. end], "ot")) return .Not;
                    if (strEq(self.code[start + 1 .. end], "il")) return .Nil;
                    return null;
                },
                'O' => if (strEq(self.code[start + 1 .. end], "wn")) return .Own else return null,
                's' => if (strEq(self.code[start + 1 .. end], "tr")) return .Str else return null,
                't' => {
                    if (strEq(self.code[start + 1 .. end], "yp")) return .Typ;
                    if (strEq(self.code[start + 1 .. end], "ag")) return .Tag;
                    return null;
                },
                'u' => if (strEq(self.code[start + 1 .. end], "se")) return .Use else return null,
                'v' => {
                    if (strEq(self.code[start + 1 .. end], "ar")) return .Var;
                    if (strEq(self.code[start + 1 .. end], "ec")) return .Vec;
                    return null;
                },
                else => return null,
            },
            4 => switch (self.code[start]) {
                'c' => if (strEq(self.code[start + 1 .. end], "ase")) return .Case else return null,
                'e' => {
                    if (strEq(self.code[start + 1 .. end], "lif")) return .Elif;
                    if (strEq(self.code[start + 1 .. end], "lse")) return .Else;
                    return null;
                },
                't' => {
                    if (strEq(self.code[start + 1 .. end], "rue")) return .True;
                    if (strEq(self.code[start + 1 .. end], "est")) return .Test;
                    return null;
                },
                else => return null,
            },
            5 => switch (self.code[start]) {
                'b' => if (strEq(self.code[start + 1 .. end], "reak")) return .Break else return null,
                'f' => if (strEq(self.code[start + 1 .. end], "alse")) return .False else return null,
                'm' => if (strEq(self.code[start + 1 .. end], "atch")) return .Match else return null,
                'y' => if (strEq(self.code[start + 1 .. end], "ield")) return .Yield else return null,
                else => return null,
            },
            6 => if (strEq(self.code[start..end], "return")) return .Return else return null,
            8 => if (strEq(self.code[start..end], "continue")) return .Continue else return null,
            else => return null,
        }
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
        self.errors.report(
            "unterminated string",
            "This string is unterminated",
            self.x_pos,
            self.y_pos,
            self.code,
        );
        return LexError.BadSyntax;
    }

    fn reportErrorUnknownOperator(self: *Lexer) LexError {
        self.errors.report(
            "unknown operator",
            "This operator is unknown",
            self.x_pos,
            self.y_pos,
            self.code,
        );
        return LexError.BadSyntax;
    }

    fn reportErrorUnexpected(self: *Lexer, comptime expect: []const u8) LexError {
        self.errors.report(
            "unexpected symbol",
            "expecting " ++ expect,
            self.x_pos,
            self.y_pos,
            self.code,
        );
        return LexError.BadSyntax;
    }

    /// Returns a single token, from the current char index slicing self.code
    /// The tokens returned will have slices of the code  as the lexeme
    pub fn scanToken(self: *Lexer) LexError!luv.Token {
        errdefer {
            self.char_index += 1;
            self.x_pos += 1;
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
    /// The tokens returned will have slices of the code argument as the lexeme
    pub fn lex(
        self: *Lexer,
        allocator: std.mem.Allocator,
        code: []const u8,
    ) !std.ArrayList(luv.Token) {
        self.code = code;

        var tokens = try std.ArrayList(luv.Token).initCapacity(allocator, 32);
        errdefer tokens.deinit(allocator); 

        while (self.char_index <= self.code.len) {
            // TODO: Dont stop the execution when encountering LexError
            try tokens.append(allocator, try self.scanToken());
        }

        return tokens;
    }
};

test "Error Recovery" {
    const t = std.testing;
    const code =
        \\+===~-==~
    ;

    var l: Lexer = .init(code);
    l.errors = ErrorReport{
        .count = 0,
        .capture = try .initCapacity(t.allocator, 32),
    };
    defer l.errors.capture.?.deinit(t.allocator);

    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(.PlusEqual, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.EqualEqual, tok.tt);

    try t.expectError(LexError.BadSyntax, l.scanToken());

    tok = try l.scanToken();
    try t.expectEqual(.MinusEqual, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Equal, tok.tt);

    try t.expectError(LexError.BadSyntax, l.scanToken());

    const expected =
        "error (1:4): unknown operator:\n" ++
        "\t+===~-==~\n" ++
        "\t    ^ This operator is unknown\n\n" ++
        "error (1:8): unknown operator:\n" ++
        "\t+===~-==~\n" ++
        "\t        ^ This operator is unknown\n\n";

    try t.expectEqualStrings(expected, l.errors.capture.?.items);
}

test "Basic Lex Error" {
    const t = std.testing;
    const code =
        \\"Hello World!
    ;

    var l: Lexer = .init(code);
    l.errors = ErrorReport{
        .count = 0,
        .capture = try .initCapacity(t.allocator, 32),
    };
    defer l.errors.capture.?.deinit(t.allocator);

    try t.expectError(LexError.BadSyntax, l.scanToken());

    const expected =
        "error (1:0): unterminated string:\n" ++
        "\t\"Hello World!\n" ++
        "\t^ This string is unterminated\n\n";

    try t.expectEqualStrings(expected, l.errors.capture.?.items);
}

test "Identifier Or Keyword" {
    const t = std.testing;

    const code =
        \\def var fun use nom
        \\typ any tag fit Own
        \\if elif else of for
        \\in match case break continue
        \\yield return not and or
        \\false true nil test flo
        \\bol str int vec
    ;

    const keywords = [_]luv.TokenType{
        .Def,   .Var,    .Fun,  .Use,   .Nom,
        .Typ,   .Any,    .Tag,  .Fit,   .Own,
        .If,    .Elif,   .Else, .Of,    .For,
        .In,    .Match,  .Case, .Break, .Continue,
        .Yield, .Return, .Not,  .And,   .Or,
        .False, .True,   .Nil,  .Test,  .Flo,
        .Bol,   .Str,    .Int,  .Vec,
    };

    var l: Lexer = .init(code);
    var tok: luv.Token = undefined;

    for (0..keywords.len) |i| {
        tok = try l.scanToken();
        try t.expectEqual(keywords[i], tok.tt);
    }
}

test "Basic string" {
    const t = std.testing;

    const code =
        \\"a"
        \\"123"
        \\"hello"
    ;

    var l: Lexer = .init(code);
    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(luv.TokenType.StringLiteral, tok.tt);
    try t.expectEqualStrings("\"a\"", tok.lexeme);

    tok = try l.scanToken();
    try t.expectEqual(luv.TokenType.StringLiteral, tok.tt);
    try t.expectEqualStrings("\"123\"", tok.lexeme);

    tok = try l.scanToken();
    try t.expectEqual(luv.TokenType.StringLiteral, tok.tt);
    try t.expectEqualStrings("\"hello\"", tok.lexeme);
}

test "Forms of Numbers" {
    const t = std.testing;

    const code =
        \\1 
        \\123
        \\12_000 
        \\0x0123456789facade
        \\0xff_ff
        \\0b00000000
        \\0b0101_0101
        \\0o01234567
        \\0o67_67_67
        \\0.0
        \\1_000.0
        \\10.0e5
        \\1.2E3
        \\3.1e-6
        \\0e1
        \\100_000e-10
    ;

    var l: Lexer = .init(code);
    var tok: luv.Token = undefined;

    for (0..9) |_| {
        tok = try l.scanToken();
        try t.expectEqual(luv.TokenType.IntLiteral, tok.tt);
    }

    for (0..7) |_| {
        tok = try l.scanToken();
        try t.expectEqual(luv.TokenType.FloatLiteral, tok.tt);
    }
}

test "Comment Ignored" {
    const t = std.testing;

    const code =
        \\ 1# this is ignored 1 + 1
        \\# this whole line should be ignored
        \\  *##
    ;

    var l: Lexer = .init(code);
    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqualStrings("1", tok.lexeme);
    try t.expectEqual(0, tok.y_pos);
    try t.expectEqual(1, tok.x_pos);

    tok = try l.scanToken();
    try t.expectEqualStrings("*", tok.lexeme);
    try t.expectEqual(2, tok.y_pos);
    try t.expectEqual(2, tok.x_pos);
}

test "Correct X position and lines" {
    const t = std.testing;

    const code =
        \\+ kanye *
        \\   -
        \\     %
    ;

    var l: Lexer = .init(code);
    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(0, tok.x_pos);
    try t.expectEqual(0, tok.y_pos);

    tok = try l.scanToken();
    try t.expectEqual(2, tok.x_pos);
    try t.expectEqual(0, tok.y_pos);

    tok = try l.scanToken();
    try t.expectEqual(8, tok.x_pos);
    try t.expectEqual(0, tok.y_pos);

    tok = try l.scanToken();
    try t.expectEqual(3, tok.x_pos);
    try t.expectEqual(1, tok.y_pos);

    tok = try l.scanToken();
    try t.expectEqual(5, tok.x_pos);
    try t.expectEqual(2, tok.y_pos);
}

test "Primitive Token" {
    const t = std.testing;
    const tt = luv.TokenType;

    const allocator = std.testing.allocator;

    var l: Lexer = .empty;

    const code =
        \\*/+%&{}()[].,;?-<>!^=
        \\.. == -> != <= >=
        \\+= -= *= /= %=
    ;

    var tokens = try l.lex(allocator, code);
    defer tokens.deinit(allocator);

    try t.expectEqual(33, tokens.items.len);

    const toks = tokens.items.ptr;
    try t.expectEqual(tt.Asterisk, toks[0].tt);
    try t.expectEqual(tt.Solidus, toks[1].tt);
    try t.expectEqual(tt.Plus, toks[2].tt);
    try t.expectEqual(tt.Modulus, toks[3].tt);
    try t.expectEqual(tt.Ampersand, toks[4].tt);
    try t.expectEqual(tt.Lbrace, toks[5].tt);
    try t.expectEqual(tt.Rbrace, toks[6].tt);
    try t.expectEqual(tt.Lparen, toks[7].tt);
    try t.expectEqual(tt.Rparen, toks[8].tt);
    try t.expectEqual(tt.Lsquare, toks[9].tt);
    try t.expectEqual(tt.Rsquare, toks[10].tt);
    try t.expectEqual(tt.Dot, toks[11].tt);
    try t.expectEqual(tt.Comma, toks[12].tt);
    try t.expectEqual(tt.Semicolon, toks[13].tt);
    try t.expectEqual(tt.QuestionMark, toks[14].tt);
    try t.expectEqual(tt.Minus, toks[15].tt);
    try t.expectEqual(tt.Less, toks[16].tt);
    try t.expectEqual(tt.Greater, toks[17].tt);
    try t.expectEqual(tt.Bang, toks[18].tt);
    try t.expectEqual(tt.Caret, toks[19].tt);
    try t.expectEqual(tt.Equal, toks[20].tt);
    try t.expectEqual(tt.DotDot, toks[21].tt);
    try t.expectEqual(tt.EqualEqual, toks[22].tt);
    try t.expectEqual(tt.Arrow, toks[23].tt);
    try t.expectEqual(tt.BangEqual, toks[24].tt);
    try t.expectEqual(tt.LessEqual, toks[25].tt);
    try t.expectEqual(tt.GreaterEqual, toks[26].tt);
    try t.expectEqual(tt.PlusEqual, toks[27].tt);
    try t.expectEqual(tt.MinusEqual, toks[28].tt);
    try t.expectEqual(tt.AsteriskEqual, toks[29].tt);
    try t.expectEqual(tt.SolidusEqual, toks[30].tt);
    try t.expectEqual(tt.ModulusEqual, toks[31].tt);
    try t.expectEqual(tt.Eof, toks[32].tt);
}
