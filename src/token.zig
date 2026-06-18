const std = @import("std");

pub const Token = enum {
    // Non visible Token
    Eof,
    Unknown,

    // single char token
    Asterisk,
    Solidus,
    Plus,
    Modulus,
    Ampersand,
    Pipe,
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
    Colon,
    Minus,
    Less,
    Greater,
    Equal,
    Bang,

    // double char token
    EqualEqual,
    Arrow,
    BangEqual,
    LessEqual,
    LessLess,
    GreaterEqual,
    GreaterGreater,
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

    // primitives
    Flt,
    Bol,
    Str,
    Int,
    Vec,
    Tup,
};
