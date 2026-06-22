const std = @import("std");
const luv = @import("root.zig");

pub const LexerError = error{
    UnterminatedString,
    InvalidOperator,
};

pub const Lexer = struct {
    char_index: usize,
    y_pos: usize,
    code: []const u8,
    x_pos: usize,

    pub const empty = Lexer {
        .char_index = 0,
        .y_pos = 0,
        .code = undefined,
        .x_pos = 0,
    };

    pub fn init(code: []const u8) Lexer {
        return .{
            .char_index = 0,
            .y_pos = 0,
            .code = code,
            .x_pos = 0,
        };
    }

    inline fn peek(self: *Lexer, num: comptime_int) ?u8 {
        if (self.char_index + num < self.code.len) {
            return self.code.ptr[self.char_index + num];
        } else {
            return null;
        }
    }

    inline fn isAlpha(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
    }

    inline fn isNumeric(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    inline fn isAlphaNumeric(ch: u8) bool {
        return isAlpha(ch) or isNumeric(ch) or ch == '_';
    }

    inline fn isHex(ch: u8) bool {
        return isNumeric(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
    }

    inline fn isOct(ch: u8) bool {
        return ch >= '0' and ch <= '7';
    }

    inline fn isBin(ch: u8) bool {
        return ch == '0' or ch == '1';
    }

    inline fn isWhitespace(ch: u8) bool {
        return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r';
    }

    inline fn makeEof(self: *Lexer) luv.Token {
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

    inline fn doubleCharToken(self: *Lexer, default_tt: luv.TokenType, peek_ch: u8, double_tt: luv.TokenType) luv.Token {
        const ch = self.peek(1);
        if (ch != null and ch.? == peek_ch) {
            self.char_index += 2;
            return self.makeToken(
                self.code[self.char_index - 2 .. self.char_index], 
                double_tt
            );
        } else {
            self.char_index += 1;
            return self.makeToken(
                self.code[self.char_index - 1 .. self.char_index],
                default_tt
            );
        }
    }

    inline fn singleCharToken(self: *Lexer, tt: luv.TokenType) luv.Token {
        self.char_index += 1;
        return self.makeToken(
            self.code[self.char_index - 1 .. self.char_index],
            tt
        );
    }

    fn primitiveToken(self: *Lexer) LexerError!luv.Token {
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
                const peek_ch = self.peek(1) orelse return self.makeEof();
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
                    return self.makeToken(
                        self.code[self.char_index - 1 .. self.char_index],
                        .Minus
                    );
                }
            },
            else => return LexerError.InvalidOperator,
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

    fn comment(self: *Lexer) void {
        self.char_index += 1;
        var ch = self.peek(0) orelse return;
        while (ch != '\n') {
            self.char_index += 1;
            ch = self.peek(0) orelse return;
        }
    }

    fn identifier(self: *Lexer) luv.Token {
        const start = self.char_index;
        var ch = self.peek(0).?;
        while (isAlphaNumeric(ch)) {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        return self.makeToken(
            self.code[start..self.char_index],
            .Identifier
        );
    }

    fn number(self: *Lexer) luv.Token {
        const start = self.char_index;
        var ch = self.peek(0).?;
        while (isNumeric(ch)) {
            self.char_index += 1;
            ch = self.peek(0) orelse break;
        }

        return self.makeToken(
            self.code[start..self.char_index],
            .IntLiteral
        );
    }

    pub fn scanToken(self: *Lexer) !luv.Token {
        var ch: u8 = undefined;
        while (true) {
            self.skipWhitespace();
            ch = self.peek(0) orelse return self.makeEof();
            if (isAlpha(ch)) {
                // TODO
                // if (ch == 'f') {
                //     const peek_ch = self.peek(1) orelse return self.identifier();
                //     if (peek_ch == '"') {
                //         return self.fstring();
                //     }
                // }
                return self.identifier();
            } else if (isNumeric(ch)) {
                // TODO
                // if (ch == '0') {
                //     const peek_ch = self.peek(1) orelse return self.number();
                //     switch (peek_ch) {
                //         'b' => return self.binNumber(),
                //         'o' => return self.octNumber(),
                //         'x' => return self.hexNumber(),
                //     }
                // }
                return self.number();
            } else if (ch == '#') {
                self.comment();
                ch = self.peek(0) orelse return self.makeEof();
            // } else if (ch == '"') {
            //     return self.string();
            } else {
                return try self.primitiveToken();
            }
        }
    }

    pub fn lex(self: *Lexer, allocator: std.mem.Allocator, code: []const u8) !std.ArrayList(luv.Token) {
        self.code = code;

        var tokens = try std.ArrayList(luv.Token).initCapacity(allocator, 32);

        while(self.char_index <= self.code.len) {
            try tokens.append(allocator, try self.scanToken());
        }

        return tokens;
    }
};

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

    var l : Lexer = .init(code);
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

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var l : Lexer = .empty;

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

