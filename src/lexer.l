%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"   /* token definitions from bison */

static void count_newlines(const char *s) {
    while (*s) { if (*s++ == '\n') yylineno++; }
}
%}

%option noyywrap
%option nounput
%option noinput

DIGIT       [0-9]
LETTER      [a-zA-Z_]
ALNUM       [a-zA-Z0-9_]
INT_LIT     {DIGIT}+
FLOAT_LIT   {DIGIT}+"."{DIGIT}+
CHAR_LIT    '([^'\\]|\\.)'
ID          {LETTER}{ALNUM}*
WS          [ \t\r]+

%%

"int"           { return KW_INT;    }
"float"         { return KW_FLOAT;  }
"char"          { return KW_CHAR;   }
"void"          { return KW_VOID;   }
"if"            { return KW_IF;     }
"else"          { return KW_ELSE;   }
"while"         { return KW_WHILE;  }
"for"           { return KW_FOR;    }
"return"        { return KW_RETURN; }

{ID}            { yylval.str = strdup(yytext); return IDENTIFIER; }

{FLOAT_LIT}     { yylval.str = strdup(yytext); return FLOAT_LITERAL; }
{INT_LIT}       { yylval.str = strdup(yytext); return INT_LITERAL;   }
{CHAR_LIT}      { yylval.str = strdup(yytext); return CHAR_LITERAL;  }

"+"             { return PLUS;    }
"-"             { return MINUS;   }
"*"             { return STAR;    }
"/"             { return SLASH;   }
"%"             { return PERCENT; }

"=="            { return EQ;  }
"!="            { return NE;  }
"<="            { return LE;  }
">="            { return GE;  }
"<"             { return LT;  }
">"             { return GT;  }

"&&"            { return AND; }
"||"            { return OR;  }
"!"             { return NOT; }

"="             { return ASSIGN; }

"("             { return LPAREN;    }
")"             { return RPAREN;    }
"{"             { return LBRACE;    }
"}"             { return RBRACE;    }
";"             { return SEMICOLON; }
","             { return COMMA;     }

"//"[^\n]*      { /* single-line comment – skip */ }
"/*"([^*]|\*+[^*/])*\*+"/" { count_newlines(yytext); /* block comment */ }

{WS}            { /* skip whitespace */ }
"\n"            { yylineno++; }

.               {
                    fprintf(stderr, "Lexical error at line %d: unknown character '%s'\n",
                            yylineno, yytext);
                    exit(1);
                }

%%
