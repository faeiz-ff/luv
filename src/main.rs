mod token;
mod lexer;
use lexer::Lexer;

use crate::token::Kind;

fn main() {
    let code = "";
    let mut l = Lexer::from(code);

    loop {
        let a = l.lex().unwrap();
        println!("{:?}", a);
        if a.kind == Kind::Eof { break }
    }
}
