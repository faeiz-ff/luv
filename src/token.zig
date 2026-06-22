const std = @import("std");

pub const Token = struct {
    tt: TokenType, 
    lexeme: []const u8,
    x_pos: usize,
    y_pos: usize,
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
    Pub,
    As,

    Nom,
    Typ,
    Any,
    Tag,
    Fit,
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
    Flt,
    Bol,
    Str,
    Int,
    Vec,
    Tup,
};
