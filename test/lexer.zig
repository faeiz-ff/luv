const std = @import("std");
const luv = @import("luv");

test "Tuple index postfix" {
    const t = std.testing;
    const code =
        \\t.1.pop()
    ;

    var writer = std.Io.Writer.Allocating.init(t.allocator);
    defer writer.deinit();

    var l: luv.Lexer = .empty;
    l.assignErr(&writer.writer);
    l.code = code; // For test only

    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(.Identifier, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Dot, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.IntLiteral, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Dot, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Identifier, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Lparen, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Rparen, tok.tt);
}

test "Error Recovery" {
    const t = std.testing;
    const code =
        \\+===~-==~
    ;

    var writer = std.Io.Writer.Allocating.init(t.allocator);
    defer writer.deinit();

    var l: luv.Lexer = .empty;
    l.assignErr(&writer.writer);
    l.code = code; // For test only

    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(.PlusEqual, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.EqualEqual, tok.tt);

    try t.expectError(luv.LexError.BadSyntax, l.scanToken());

    tok = try l.scanToken();
    try t.expectEqual(.MinusEqual, tok.tt);

    tok = try l.scanToken();
    try t.expectEqual(.Equal, tok.tt);

    try t.expectError(luv.LexError.BadSyntax, l.scanToken());
}

test "Basic Lex Error" {
    const t = std.testing;
    const code =
        \\"Hello World!
    ;

    var writer = std.Io.Writer.Allocating.init(t.allocator);
    defer writer.deinit();

    var l: luv.Lexer = .empty;
    l.assignErr(&writer.writer);
    l.code = code; // For test only

    try t.expectError(luv.LexError.BadSyntax, l.scanToken());
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

    var l: luv.Lexer = .empty;
    l.code = code; // For test only

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

    var l: luv.Lexer = .empty;
    l.code = code; // For test only

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

    var l: luv.Lexer = .empty;
    l.code = code; // For test only

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

    var l: luv.Lexer = .empty;
    l.code = code; // For test only

    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqualStrings("1", tok.lexeme);
    try t.expectEqual(0, tok.pos.y);
    try t.expectEqual(1, tok.pos.x);

    tok = try l.scanToken();
    try t.expectEqualStrings("*", tok.lexeme);
    try t.expectEqual(2, tok.pos.y);
    try t.expectEqual(2, tok.pos.x);
}

test "Correct X position and lines" {
    const t = std.testing;

    const code =
        \\+ kanye *
        \\   -
        \\     %
    ;

    var l: luv.Lexer = .empty;
    l.code = code; // For test only

    var tok: luv.Token = undefined;

    tok = try l.scanToken();
    try t.expectEqual(0, tok.pos.x);
    try t.expectEqual(0, tok.pos.y);

    tok = try l.scanToken();
    try t.expectEqual(2, tok.pos.x);
    try t.expectEqual(0, tok.pos.y);

    tok = try l.scanToken();
    try t.expectEqual(8, tok.pos.x);
    try t.expectEqual(0, tok.pos.y);

    tok = try l.scanToken();
    try t.expectEqual(3, tok.pos.x);
    try t.expectEqual(1, tok.pos.y);

    tok = try l.scanToken();
    try t.expectEqual(5, tok.pos.x);
    try t.expectEqual(2, tok.pos.y);
}

test "Primitive Token" {
    const t = std.testing;
    const tt = luv.TokenType;

    const allocator = std.testing.allocator;

    const code =
        \\*/+%&{}()[].,;?-<>!^=
        \\.. == -> != <= >=
        \\+= -= *= /= %=
    ;

    var l: luv.Lexer = .empty;

    var tokens = try l.lexAll(allocator, code);
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
