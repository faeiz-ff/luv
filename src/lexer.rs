use crate::token::{Kind, Token};

pub struct Lexer<'a> {
    src: &'a str,
    line: usize,
    pos: usize,
    insert_newline: bool,
}

#[derive(Debug)]
pub enum LexerError {
    NumberIdentifier,
    UnknownSymbol,
}

impl<'a> Lexer<'a> {
    pub fn from(src: &'a str) -> Self {
        if !src.is_ascii() {
            unimplemented!("Can only lex ascii chars");
        }

        Self {
            src,
            line: 1,
            pos: 0,
            insert_newline: false,
        }
    }

    fn eof(&self) -> Token {
        Token {
            kind: Kind::Eof,
            line: self.line,
            start: self.pos,
            end: self.pos + 1,
        }
    }

    fn advance(&mut self) {
        self.pos += 1;
        if let Some(c) = self.curr()
            && c == b'\n'
        {
            self.line += 1
        }
    }

    fn curr(&self) -> Option<u8> {
        if self.pos < self.src.len() {
            Some(self.src.as_bytes()[self.pos])
        } else {
            None
        }
    }

    fn peek(&self) -> Option<u8> {
        if self.pos + 1 < self.src.len() {
            Some(self.src.as_bytes()[self.pos + 1])
        } else {
            None
        }
    }

    fn lex_number(&mut self) -> Result<Token, LexerError> {
        let start = self.pos;
        let mut is_float = false;

        'outer: while let Some(c) = self.curr() {
            if c.is_ascii_alphabetic() {
                return Err(LexerError::NumberIdentifier);
            }
            match c {
                b'0'..=b'9' | b'_' => {}
                b'.' if !is_float => is_float = true,
                _ => break 'outer,
            }
            self.advance();
        }

        return Ok(Token {
            kind: if is_float {
                Kind::FloatLiteral
            } else {
                Kind::IntLiteral
            },
            line: self.line,
            start,
            end: self.pos,
        });
    }

    fn lex_keyword(&self, start: usize) -> Option<Kind> {
        let lexeme = &self.src[start..self.pos];
        let kind = match lexeme {
            "if" => Kind::If,
            "let" => Kind::Let,
            _ => return None,
        };

        Some(kind)
    }

    fn lex_id(&mut self) -> Token {
        let start = self.pos;

        while let Some(c) = self.curr()
            && (c.is_ascii_alphabetic() || c == b'_')
        {
            self.advance();
        }

        let kind = match self.lex_keyword(start) {
            Some(kind) => kind,
            None => Kind::Identifier,
        };

        Token {
            kind,
            line: self.line,
            start,
            end: self.pos,
        }
    }

    fn lex_symbols(&mut self) -> Result<Token, LexerError> {
        let start = self.pos;

        let Some(ch) = self.curr() else {
            return Ok(self.eof());
        };

        let kind = match ch {
            b'+' => Kind::Plus,
            b'-' => Kind::Minus,
            b'*' => Kind::Star,
            b'/' => Kind::Slash,
            b';' => Kind::Semicolon,
            b',' => Kind::Comma,
            b'\n' => Kind::Newline,
            b'(' => Kind::LParen,
            b')' => Kind::RParen,
            b'{' => Kind::LCurly,
            b'}' => Kind::RCurly,
            b'[' => Kind::LSquare,
            b']' => Kind::RSquare,
            b'=' => Kind::Equal,
            _ => return Err(LexerError::UnknownSymbol),
        };

        self.advance();

        Ok(Token {
            kind,
            line: self.line,
            start,
            end: self.pos,
        })
    }

    fn skip_whitespace(&mut self) {
        while let Some(c) = self.curr()
            && matches!(c, b' ' | b'\t' | b'\r')
        {
            self.advance();
        }
    }

    fn skip_comments(&mut self) {
        if let (Some(c), Some(d)) = (self.curr(), self.peek())
            && c == b'/'
            && d == b'/'
        {
            self.advance();
            self.advance();
        } else {
            return;
        }
        while let Some(c) = self.curr()
            && c != b'\n'
        {
            self.advance();
        }
        self.skip_whitespace();
    }

    fn can_insert_newline(&self, kind: &Kind) -> bool {
        matches!(
            kind,
            Kind::Identifier | Kind::IntLiteral | Kind::RParen | Kind::RCurly | Kind::RSquare
        )
    }

    pub fn lex(&mut self) -> Result<Token, LexerError> {
        self.skip_whitespace();
        self.skip_comments();

        let Some(mut ch) = self.curr() else {
            return Ok(self.eof());
        };

        while ch == b'\n' && !self.insert_newline {
            self.advance();
            self.skip_whitespace();
            self.skip_comments();
            ch = match self.curr() {
                Some(ch) => ch,
                None => return Ok(self.eof()),
            }
        }

        let tok = match ch {
            b'0'..=b'9' => self.lex_number()?,
            b'A'..=b'Z' | b'a'..=b'z' => self.lex_id(),
            _ => self.lex_symbols()?,
        };

        self.insert_newline = self.can_insert_newline(&tok.kind);
        Ok(tok)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use Kind::*;

    fn token_kinds(src: &str) -> Vec<Kind> {
        let mut l = Lexer::from(src);
        let mut out: Vec<Kind> = Vec::new();

        loop {
            let tok = l.lex().expect("Unexpected");
            if tok.kind == Kind::Eof {
                break;
            }
            out.push(tok.kind);
        }

        out
    }

    #[test]
    fn basic_functionality() {
        assert_eq!(
            token_kinds("1 + 2 + 3 + 4"),
            vec![
                IntLiteral, Plus, IntLiteral, Plus, IntLiteral, Plus, IntLiteral,
            ]
        )
    }

    #[test]
    fn can_insert_semicolon() {
        assert_eq!(
            token_kinds("\n { \n 123 \n 234 \n 345 \n }"),
            vec![
                LCurly, IntLiteral, Newline, IntLiteral, Newline, IntLiteral, Newline, RCurly
            ]
        )
    }

    #[test]
    fn can_not_insert_semicolon() {
        assert_eq!(
            token_kinds("1 + \n 2 , \n 3 + 4"),
            vec![
                IntLiteral, Plus, IntLiteral, Comma, IntLiteral, Plus, IntLiteral,
            ]
        )
    }
}
