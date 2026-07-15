```g4
grammar luv;

program: topLevelStmt* EOF;

topLevelStmt
    : ( typStmt
      | useStmt
      | defTopStmt
      | funStmt 
      ) ';'?
    ;

useStmt: use' ID '=' STRING_LITERAL;

tagType: 'tag' '{' (ID typeRule ','?)+ '}';

nomType: 'nom' '{' ('def'? '^'? ID typeRule ','?)* '}';

symType: 'sym' '{' (ID ('=' expr)? ','?)+ '}';

fitType: 'fit' '{' ('def'? (ID (typeRule | 'Own' '?') | methodDecl) ','?)* '}';

typStmt: 'typ' '^'? nameSpacedIdentifier genericDeclaration? (tagType | nomType | fitType | typeRule);

methodDecl: ID '(' ((typeRule | 'Own') (',' (typeRule | 'Own'))* (',' '..' (typeRule | 'Own'))? | ('..' (typeRule | 'Own')))? ','? ')' (typeRule | 'Own');

genericDeclaration: '[' ID typeRule (',' ID typeRule)* ','? ']';

genericFulfill: '[' typeRule (',' typeRule)* ','? ']';

typeRule: typePostFix ('!' typePostFix)?;

typePostFix: typeBase ('&' | '?' | genericFulfill)*;

typeBase
    : nameSpacedIdentifier
    | 'fun' '(' (typeRule (',' typeRule)* (',' '..' typeRule)? | '..' typeRule)? ','? ')' typeRule
    | '[' typeRule ']'
    | '[' typeRule (',' typeRule)+ ']'
    | '[' ']'
    | fitType
    | symType
    | 'nil'
    | 'any'
    | 'int' | 'flo' | 'str' | 'bol'
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

patternMatch: ID (',' ID)*;

typePattern: (typeRule | '&' | '?');

capturePattern: ('var' | 'def') patternMatch;

defTopStmt
    : 'def' '^'? nameSpacedIdentifier (typeRule | '&' | '?')? '=' expr
    | 'def' 'test' STRING_LITERAL blockStmt
    ;

defStmt: 'def' patternMatch typePattern? '=' expr;

varStmt: 'var' patternMatch typePattern? '=' expr;

funParams: '(' (ID typeRule (',' ID typeRule)* (',' '..' ID typeRule)? | '..' ID typeRule)? ','? ')';

funStmt
    : 'fun' '^'? nameSpacedIdentifier genericDeclaration? funParams typeRule? blockStmt
    | 'fun' 'test' ID genericDeclaration? funParams typeRule? blockStmt
    ;

expr
    : ifExpr
    | matchExpr
    | lambdaExpr
    | forExpr
    | assignment
    ;

varGuard: capturePattern (typePattern | 'of' ID)? '=' postFixExpr;

ifGuard
    : varGuard ('and' varGuard)* ('and' expr)?
    | expr
    ;

ifExpr: 'if' ifGuard (blockStmt | '->' expr) ('elif' ifGuard (blockStmt | '->' expr ))* ('else' (blockStmt | '->' expr))?;

matchExpr: 'match' expr '{' (matchCase | matchTag) ((('var' | 'def') ID)? 'else' ('->' expr | blockStmt))?'}';

matchCase: ('case' expr (',' expr)* ('->' expr | blockStmt) ';'?)+;

matchTag: ((patternMatch 'of')? ID ('->' expr | blockStmt) ';'?)+;

lambdaExpr: 'fun' genericDeclaration? funParams typeRule? blockStmt;

forExpr
    : 'for' capturePattern typePattern? 'in' expr blockStmt
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
    | 'int' | 'flo' | 'str' | 'bol'
    | '(' expr ')'
    ;

objLiteral: '{' (('..' postFixExpr | 'def'? ID '=' expr) ','?)+ '}';

tupLiteral: '(' (orExpr (',' orExpr)*)? ','? ')';

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

callSuffix: '(' ('..'? expr (',' '..'? expr)*)? ','? ')';

dotSuffix
    : '.' ID
    | '.' objLiteral
    | '.' tupLiteral
    | '.' INT_LITERAL
    ; 

nameSpacedIdentifier: ID ('.' ID)*;

// Lexer

ID: [a-zA-Z_] [a-zA-Z_0-9]*;

STRING_LITERAL: '"' .*? '"';

FLOAT_LITERAL
    : [0-9] [0-9_]* '.' [0-9_]+ ([eE] '-'? [0-9]+)?
    | [0-9] [0-9_]* [eE] '-'? [0-9]+
    ;

INT_LITERAL
    : [0-9] [0-9_]*
    | '0x' [0-9a-fA-F_]+
    | '0b' [01_]+
    | '0o' [0-7_]+
    ;

WS: [ \t\r\n]+ -> skip;
COMMENT: '#' ~[\n\r]* -> skip;
```
