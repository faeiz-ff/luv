
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Plus,
    Minus,
    Star,
    Slash,
    IntLiteral,
    FloatLiteral,
    Semicolon,
    Comma,
    Newline,
    Identifier,
    LParen,
    RParen,
    LCurly,
    RCurly,
    LSquare,
    RSquare,
    Equal,
    If,
    Let,
    Eof,
}

#[derive(Debug)]
pub struct Token {
    pub kind: Kind,
    pub line: usize,
    pub start: usize,
    pub end: usize,
}
