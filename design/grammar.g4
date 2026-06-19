grammar luv;

program: topLevelStmt* EOF;

topLevelStmt
    : ( typStmt
      | useStmt
      | defTopStmt
      | funStmt 
      ) ';'?
    ;

useStmt : 'use' STRING_LITERAL ('as' ID)?;

tupType: 'tup' '{' (typeRule (';'|',')?)+ '}';

tagType: 'tag' genericDeclaration? '{' (ID typeRule ';'?)+ '}';

nomType: 'nom' genericDeclaration? '{' ('def'? ID typeRule ';'?)* '}';

symType: 'sym' '{' (ID ('=' expr)? (';' | ',')?)+ '}';

fitType: 'fit' genericDeclaration? '{' ('def'? (ID (typeRule | 'Own' '?') | methodDecl) ';'?)+ '}';

typStmt: 'typ' ID (tagType | nomType | fitType | typeRule);

methodDecl: ID '(' ((typeRule | 'Own') (',' (typeRule | 'Own'))* (',' '..' (typeRule | 'Own'))? | ('..' (typeRule | 'Own')))? ')' (typeRule | 'Own');

genericDeclaration: '[' ID typeRule (',' ID typeRule)* ']';

genericFulfill: '[' typeRule (',' typeRule)* ']';

typeRule: typePostFix ('!' typePostFix)?;

typePostFix: typeBase ('&' | '?' | genericFulfill)*;

typeBase
    : nameSpacedIdentifier
    | 'fun' '(' (typeRule (',' typeRule)* (',' '..' typeRule)? | '..' typeRule)? ')' typeRule
    | '[' typeRule ']'
    | 'fit' '{' ('def'? (ID typeRule | methodDecl) ';'?)* '}'
    | symType
    | tupType
    | 'nil'
    | 'any'
    | 'int' | 'flo' | 'str' | 'bol' | 'vec' | 'arr'
    ;

stmt
    : varStmt
    | defStmt
    | blockStmt
    | 'continue'
    | 'yield' expr?
    | 'break' expr?
    | 'return' expr?
    | expr
    ;

blockStmt: '{' (stmt ';'?)* '}';

varPattern
    : ID (typeRule | '&' | '?')?
    | '{' (ID (',' ID)*)? '}'
    ;

defTopStmt: 'def' nameSpacedIdentifier (typeRule | '&' | '?')? '=' expr;
defStmt: 'def' varPattern '=' expr;
varStmt: 'var' varPattern '=' expr;

funStmt: 'fun' nameSpacedIdentifier genericDeclaration? '(' (ID typeRule (',' ID typeRule)* (',' '..' ID typeRule)? | '..' ID typeRule)? ')' typeRule? blockStmt;

expr
    : ifExpr
    | matchExpr
    | lambdaExpr
    | forExpr
    | assignment
    ;

varGuard: ('var' | 'def') varPattern '=' postFixExpr;
ifGuard
    : varGuard ('and' varGuard)* ('and' expr)?
    | expr
    ;

ifExpr: 'if' ifGuard (blockStmt | '->' expr) ('elif' ifGuard (blockStmt | '->' expr ))* ('else' (blockStmt | '->' expr))?;

matchExpr: 'match' expr '{' (matchCase | matchTag) (ID? 'else' ('->' expr | blockStmt))?'}';
matchCase: ('case' expr (',' expr)* ('->' expr | blockStmt) ';'?)+;
matchTag: (ID ID? ('->' expr | blockStmt) ';'?)+;

lambdaExpr: 'fun' genericDeclaration? '(' (ID typeRule (',' ID typeRule)*)? ')' typeRule? blockStmt;

forExpr
    : 'for' ('var' | 'def') varPattern 'in' expr blockStmt
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

postFixExpr: primaryExpr ( dotSuffix | genericFulfill | callSuffix | '?' | '!' )*;

primaryExpr
    : literal
    | ID
    | 'int' | 'flo' | 'str' | 'bol' | 'vec' | 'arr'
    | '(' expr ')'
    ;

objLiteral: '{' (('..' postFixExpr | 'def'? ID '=' expr) ','?)* '}';
tupLiteral: '{' (orExpr (',' orExpr)*)? '}';

literal
    : STRING_LITERAL
    | INT_LITERAL
    | FLOAT_LITERAL
    | objLiteral
    | tupLiteral
    | 'true'
    | 'false'
    | 'nil'
    ;

callSuffix: '(' (expr (',' expr)*)? ')';
dotSuffix
    : '.' ID
    | '.' objLiteral
    | '.' tupLiteral
    ; 

nameSpacedIdentifier: ID ('.' ID)*;

// Lexer

ID: [a-zA-Z_] [a-zA-Z_0-9]*;

STRING_LITERAL: '"' .*? '"';

FLOAT_LITERAL
    : [0-9] [0-9_]+ '.' [0-9_]+ ([eE] '-'? [0-9]+)?
    | [0-9] [0-9_]+ [eE] '-'? [0-9]+
    ;

INT_LITERAL
    : [0-9] [0-9_]*
    | '0x' [0-9a-fA-F_]+
    | '0b' [01_]+
    | '0o' [0-7_]+
    ;

WS: [ \t\r\n]+ -> skip;
COMMENT: '#' ~[\n\r]* -> skip;
