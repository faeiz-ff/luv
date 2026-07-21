const std = @import("std");

pub const Position = struct { x: u32, y: u32 };

pub const Token = struct {
    tt: TokenType,
    lexeme: []const u8,
    pos: Position,
};

pub const TokenType = enum {
    // Non visible Token
    Eof,
    Unknown,

    // single char token
    Asterisk,
    Solidus,
    Plus,
    Modulus,
    Ampersand,
    Lbrace,
    Rbrace,
    Lparen,
    Rparen,
    Lsquare,
    Rsquare,
    Dot,
    Comma,
    Semicolon,
    QuestionMark,
    Minus,
    Less,
    Greater,
    Equal,
    Bang,
    Caret,

    // double char token
    DotDot,
    EqualEqual,
    Arrow,
    BangEqual,
    LessEqual,
    GreaterEqual,
    PlusEqual,
    MinusEqual,
    AsteriskEqual,
    SolidusEqual,
    ModulusEqual,

    // literals
    IntLiteral,
    FloatLiteral,
    StringLiteral,

    // names
    Identifier,

    // keywords
    Def,
    Var,
    Fun,
    Use,
    Mod,

    Nom,
    Typ,
    Any,
    Tag,
    Fit,
    Sym,
    Own,

    If,
    Elif,
    Else,
    Of,
    For,
    In,
    Match,
    Case,
    Break,
    Continue,
    Yield,
    Return,

    Not,
    And,
    Or,
    False,
    True,
    Nil,
    Test,

    // primitives
    Flo,
    Bol,
    Str,
    Int,
    Vec,
};
