grammar luv;

program: topLevelStmt* EOF;

topLevelStmt
    : ( typStmt
      | useStmt
      | defStmt
      | funStmt 
      ) ';'?
    ;

useStmt
    : 'use' STRING_LITERAL ('as' ID)?
    | 'use' nameSpacedIdentifier ('as' ID)?
    ;

tagType: 'tag' genericDeclaration? '{' (ID typeRule ';'?)+ '}';

nomType: 'nom' genericDeclaration? '{' (ID typeRule ';'?)* '}';

symType: 'sym' '{' (ID ('=' expr)? (';' | ',')?)+ '}';

fitType: 'fit' genericDeclaration? '{' ((ID (typeRule | 'Own' '?') | methodDecl) ';'?)+ '}';

typStmt: 'typ' ID (symType | tagType | nomType | fitType | typeRule);

methodDecl: ID '(' ((typeRule | 'Own') (',' (typeRule | 'Own'))*)? ')' (typeRule | 'Own');

genericDeclaration: '[' ID typeRule (',' ID typeRule)* ']';

genericFulfill: '[' typeRule (',' typeRule)* ']';

typeRule: typeBase '?'* ('!' typeBase '?'*)*;

typeBase
    : nameSpacedIdentifier genericFulfill?
    | 'fun' '(' (typeRule (',' typeRule)*)? ')' typeRule
    | '[' typeRule ']'
    | 'fit' '{' ((ID typeRule | methodDecl) ';'?)* '}'
    | symType
    ;

objLiteral: '{' (ID '=' expr ','?)* '}';

stmt
    : defStmt
    | funStmt
    | varStmt
    | blockStmt
    | 'continue'
    | 'yield' expr?
    | 'break' expr?
    | 'return' expr?
    | expr
    ;

blockStmt: '{' (stmt ';'?)* '}';

defStmt: 'def' nameSpacedIdentifier typeRule? '=' expr;

varStmt: 'var' ID typeRule? '=' expr;

funStmt: 'fun' nameSpacedIdentifier genericDeclaration? '(' (ID typeRule (',' ID typeRule)*)? ')' typeRule? blockStmt;

expr
    : ifExpr
    | matchExpr
    | lambdaExpr
    | forExpr
    | assignment
    ;

ifExpr: 'if' expr (blockStmt | '->' expr) ('elif' expr (blockStmt | '->' expr))* ('else' (blockStmt | '->' expr))?;

matchExpr
    : 'match' expr '{' (expr (',' expr)* ('->' expr | blockStmt) ';'?)* ('else' ('->' expr | blockStmt))? '}'
    | 'match' 'tag' expr '{' (ID ID? ('->' expr | blockStmt) ';'?)* ('else' ID? ('->' expr | blockStmt))? '}'
    ;

lambdaExpr: 'fun' genericDeclaration? '(' (ID typeRule (',' ID typeRule)*)? ')' typeRule? blockStmt;

forExpr
    : 'for' 'var' ID 'in' expr blockStmt
    | 'for' blockStmt
    | 'for' expr blockStmt
    ;

assignment: orExpr (('=' | '+=' | '-=' | '*=' | '/=' | '%=') expr)?;
orExpr: andExpr ('or' andExpr)*;
andExpr: relationalExpr ('and' relationalExpr)*;
relationalExpr: termExpr (('>' | '<' | '>=' | '<=' | '==' | '!=') termExpr)?;
termExpr: factorExpr (('+' | '-') factorExpr)*;
factorExpr: unaryExpr (('*' | '/' | '%') unaryExpr)*;
unaryExpr: postFixExpr | ('not' | '-') unaryExpr;

postFixExpr: primaryExpr ( dotSuffix | indexSuffix | callSuffix | '?' | '!' )*;

primaryExpr
    : literal
    | ID
    | '(' expr ')'
    ;

literal
    : STRING_LITERAL
    | INT_LITERAL
    | FLOAT_LITERAL
    | objLiteral
    ;

indexSuffix: '[' expr ']';
callSuffix: ('.' genericFulfill)? '(' (expr (',' expr)*)? ')';
dotSuffix: '.' ID; 

nameSpacedIdentifier: ID ('.' ID)*;

// Lexer

ID: [a-zA-Z_] [a-zA-Z_0-9]*;

STRING_LITERAL: '"' .*? '"';

FLOAT_LITERAL
    : [0-9]* '.' [0-9]+ ([eE] '-'? [0-9]+)?
    | [0-9]* [eE] '-'? [0-9]+
    ;

INT_LITERAL
    : [0-9]+
    | '0x' [0-9a-fA-F]+
    | '0b' [01]+
    | '0o' [0-7]+
    ;

WS: [ \t\r\n]+ -> skip;
