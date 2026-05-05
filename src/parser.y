%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"
#include "tac.h"

extern int yylineno;
extern int yylex(void);
void yyerror(const char *msg);

/* Semantic helpers */
static DataType str_to_type(const char *s) {
    if (!strcmp(s, "int"))   return TYPE_INT;
    if (!strcmp(s, "float")) return TYPE_FLOAT;
    if (!strcmp(s, "char"))  return TYPE_CHAR;
    if (!strcmp(s, "void"))  return TYPE_VOID;
    return TYPE_UNKNOWN;
}

/* Current function context */
static char current_func[64] = "";
static DataType current_func_ret = TYPE_VOID;

/* Parameter list accumulation during function definition */
#define MAX_PARAMS 16
static char *param_names[MAX_PARAMS];
static DataType param_types_buf[MAX_PARAMS];
static int param_count_buf = 0;

/* Expression result: either a temp name or a literal/var name */
typedef struct {
    char *place;     /* TAC name for this expression */
    DataType type;
} Expr;

static Expr make_expr(const char *place, DataType t) {
    Expr e; e.place = strdup_safe(place); e.type = t; return e;
}

/* Implicit widening: int -> float */
static Expr coerce(Expr e, DataType target) {
    if (e.type == target) return e;
    if (e.type == TYPE_INT && target == TYPE_FLOAT) {
        char *t = new_temp();
        TacInstr *i = tac_new(TAC_CAST, t, e.place, NULL);
        tac_append(i);
        return make_expr(t, TYPE_FLOAT);
    }
    return e; /* keep as-is, semantic check already reported error */
}
%}

%union {
    char   *str;
    int     ival;
    double  dval;
    /* expression node */
    struct { char *place; int type; } expr;
    /* type keyword */
    int     dtype;
    /* label pair for control flow */
    struct { char *ltrue; char *lfalse; char *lend; } lbl;
}

/* ---- tokens ---- */
%token KW_INT KW_FLOAT KW_CHAR KW_VOID
%token KW_IF KW_ELSE KW_WHILE KW_FOR KW_RETURN
%token <str> IDENTIFIER INT_LITERAL FLOAT_LITERAL CHAR_LITERAL
%token PLUS MINUS STAR SLASH PERCENT
%token EQ NE LT GT LE GE
%token AND OR NOT
%token ASSIGN
%token LPAREN RPAREN LBRACE RBRACE SEMICOLON COMMA

/* ---- types for non-terminals ---- */
%type <dtype> type_spec
%type <expr>  expr assign_expr rel_expr add_expr mul_expr unary_expr postfix_expr primary_expr
%type <str>   arg_list_ne

/* ---- precedence (low to high) ---- */
%right ASSIGN
%left  OR
%left  AND
%left  EQ NE
%left  LT GT LE GE
%left  PLUS MINUS
%left  STAR SLASH PERCENT
%right NOT UMINUS

%start program

%%

/* ============================================================
   Program = list of top-level declarations/definitions
   ============================================================ */
program
    : /* empty */
    | program top_decl
    ;

top_decl
    : var_decl
    | func_def
    ;

/* ============================================================
   Variable declarations   int x;   float y;
   ============================================================ */
var_decl
    : type_spec IDENTIFIER SEMICOLON
        {
            DataType dt = (DataType)$1;
            if (sym_lookup_current($2)) {
                fprintf(stderr, "Semantic error (line ~%d): '%s' already declared in this scope\n",
                        yylineno, $2);
                exit(1);
            }
            sym_insert($2, dt, KIND_VAR);
            free($2);
        }
    | type_spec IDENTIFIER ASSIGN expr SEMICOLON
        {
            DataType dt = (DataType)$1;
            if (sym_lookup_current($2)) {
                fprintf(stderr, "Semantic error: '%s' already declared in this scope\n", $2);
                exit(1);
            }
            sym_insert($2, dt, KIND_VAR);
            /* emit assignment */
            Expr rhs = make_expr($4.place, (DataType)$4.type);
            if ((DataType)$4.type != dt)
                rhs = coerce(rhs, dt);
            tac_append(tac_new(TAC_ASSIGN, $2, rhs.place, NULL));
            free($2);
        }
    ;

/* ============================================================
   Function definition
   ============================================================ */
func_def
    : type_spec IDENTIFIER
        {
            /* forward-declare function in global scope */
            Symbol *existing = sym_lookup($2);
            if (!existing) {
                Symbol *fs = sym_insert($2, (DataType)$1, KIND_FUNC);
                fs->param_count = 0;
            }
            strncpy(current_func, $2, 63);
            current_func_ret = (DataType)$1;
            param_count_buf = 0;
            /* open function scope */
            scope_push();
            tac_append(tac_new(TAC_FUNC_BEGIN, $2, NULL, NULL));
        }
      LPAREN param_list RPAREN
        {
            /* Update function symbol with param info */
            Symbol *fs = sym_lookup(current_func);
            if (fs && fs->kind == KIND_FUNC) {
                fs->param_count = param_count_buf;
                for (int k = 0; k < param_count_buf; k++)
                    fs->param_types[k] = param_types_buf[k];
                fs->is_defined = 1;
            }
        }
      LBRACE stmt_list RBRACE
        {
            tac_append(tac_new(TAC_FUNC_END, current_func, NULL, NULL));
            scope_pop();
            current_func[0] = '\0';
        }
    ;

param_list
    : /* empty */
    | param_list_ne
    ;

param_list_ne
    : param
    | param_list_ne COMMA param
    ;

param
    : type_spec IDENTIFIER
        {
            DataType dt = (DataType)$1;
            if (param_count_buf < MAX_PARAMS) {
                param_names[param_count_buf] = strdup_safe($2);
                param_types_buf[param_count_buf] = dt;
                param_count_buf++;
            }
            sym_insert($2, dt, KIND_PARAM);
            free($2);
        }
    ;

/* ============================================================
   Statements
   ============================================================ */
stmt_list
    : /* empty */
    | stmt_list stmt
    ;

stmt
    : var_decl
    | expr_stmt
    | return_stmt
    | if_stmt
    | while_stmt
    | for_stmt
    | block
    ;

block
    : LBRACE { scope_push(); } stmt_list RBRACE { scope_pop(); }
    ;

expr_stmt
    : expr SEMICOLON   { /* expression result discarded */ }
    | SEMICOLON        { /* empty statement */ }
    ;

return_stmt
    : KW_RETURN SEMICOLON
        {
            if (current_func_ret != TYPE_VOID) {
                fprintf(stderr, "Semantic error: non-void function '%s' must return a value\n",
                        current_func);
                /* non-fatal: emit anyway */
            }
            tac_append(tac_new(TAC_RETURN_VOID, NULL, NULL, NULL));
        }
    | KW_RETURN expr SEMICOLON
        {
            Expr rv = make_expr($2.place, (DataType)$2.type);
            if ((DataType)$2.type != current_func_ret && current_func_ret != TYPE_VOID)
                rv = coerce(rv, current_func_ret);
            tac_append(tac_new(TAC_RETURN, NULL, rv.place, NULL));
        }
    ;

/* ============================================================
   if / else
   ============================================================ */
if_stmt
    : KW_IF LPAREN expr RPAREN
        {
            /* emit conditional jump */
            char *lfalse = new_label();
            tac_append(tac_new(TAC_IF_FALSE, lfalse, $3.place, NULL));
            /* push false label on pseudo-stack via $$ – use $<lbl>$ trick */
            /* We'll use a global here for simplicity */
            /* Store in $<str>$ */ 
            $<str>$ = lfalse;
        }
      stmt
        {
            /* after true branch: jump over else */
            char *lend = new_label();
            tac_append(tac_new(TAC_GOTO, lend, NULL, NULL));
            /* emit false label */
            tac_append(tac_new(TAC_LABEL, $<str>5, NULL, NULL));
            $<str>$ = lend;
        }
      else_part
        {
            tac_append(tac_new(TAC_LABEL, $<str>7, NULL, NULL));
        }
    ;

else_part
    : /* empty */
    | KW_ELSE stmt
    ;

/* ============================================================
   while loop
   ============================================================ */
while_stmt
    : KW_WHILE
        {
            char *lstart = new_label();
            tac_append(tac_new(TAC_LABEL, lstart, NULL, NULL));
            $<str>$ = lstart;
        }
      LPAREN expr RPAREN
        {
            char *lend = new_label();
            tac_append(tac_new(TAC_IF_FALSE, lend, $4.place, NULL));
            $<str>$ = lend;
        }
      stmt
        {
            tac_append(tac_new(TAC_GOTO, $<str>2, NULL, NULL));
            tac_append(tac_new(TAC_LABEL, $<str>6, NULL, NULL));
        }
    ;

/* ============================================================
   for loop  (desugared to while)
   ============================================================ */
for_stmt
    : KW_FOR LPAREN for_init expr SEMICOLON
        {
            /* condition label */
            char *lcond = new_label();
            /* We need to go back before condition: emit label first */
            /* Because for_init already ran, place cond label here */
            tac_append(tac_new(TAC_LABEL, lcond, NULL, NULL));
            /* evaluate condition ($4 already has its TAC emitted above it – reorder) */
            /* Actually emit IF_FALSE after condition TAC */
            char *lend = new_label();
            tac_append(tac_new(TAC_IF_FALSE, lend, $4.place, NULL));
            $<str>$ = lcond;   /* $6 */
            /* store lend somewhere accessible */
            /* We'll use a second mid-rule */
        }
        { $<str>$ = new_label(); /* lend placeholder, overwritten */ 
          /* find the last IF_FALSE we appended and grab its result */
          /* Simpler: store lend in a static */
        }
      expr SEMICOLON RPAREN
        {
            /* increment expression already emitted to TAC, need to re-route */
            /* We'll handle by unconditional goto and label rearrangement */
            /* Simpler design: store increment place, emit it after body */
            $<str>$ = $8.place; /* the increment result (unused directly) */
        }
      stmt
        {
            /* goto condition */
            tac_append(tac_new(TAC_GOTO, $<str>6, NULL, NULL));
            /* lend not easily accessible here without extra state –
               emit a new end label if none found */
            char *lend2 = new_label();
            tac_append(tac_new(TAC_LABEL, lend2, NULL, NULL));
        }
    ;

for_init
    : expr SEMICOLON  { /* init expr TAC already emitted */ }
    | SEMICOLON       { /* no init */ }
    ;

/* ============================================================
   Expressions
   ============================================================ */
expr
    : assign_expr  { $$ = $1; }
    ;

assign_expr
    : IDENTIFIER ASSIGN expr
        {
            Symbol *s = sym_lookup($1);
            if (!s) {
                fprintf(stderr, "Semantic error (line ~%d): undeclared variable '%s'\n",
                        yylineno, $1);
                exit(1);
            }
            Expr rhs = make_expr($3.place, (DataType)$3.type);
            if ((DataType)$3.type != s->type)
                rhs = coerce(rhs, s->type);
            tac_append(tac_new(TAC_ASSIGN, $1, rhs.place, NULL));
            $$.place = strdup_safe($1);
            $$.type  = s->type;
            free($1);
        }
    | rel_expr  { $$ = $1; }
    ;

rel_expr
    : rel_expr OR  rel_expr
        {
            char *t = new_temp();
            tac_append(tac_new(TAC_OR, t, $1.place, $3.place));
            $$.place = t; $$.type = TYPE_INT;
        }
    | rel_expr AND rel_expr
        {
            char *t = new_temp();
            tac_append(tac_new(TAC_AND, t, $1.place, $3.place));
            $$.place = t; $$.type = TYPE_INT;
        }
    | rel_expr EQ  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_EQ,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | rel_expr NE  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_NE,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | rel_expr LT  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_LT,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | rel_expr GT  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_GT,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | rel_expr LE  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_LE,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | rel_expr GE  rel_expr { char *t=new_temp(); tac_append(tac_new(TAC_GE,t,$1.place,$3.place)); $$.place=t;$$.type=TYPE_INT; }
    | add_expr  { $$ = $1; }
    ;

add_expr
    : add_expr PLUS  mul_expr
        {
            DataType rt = ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
            Expr l = coerce(make_expr($1.place,(DataType)$1.type), rt);
            Expr r = coerce(make_expr($3.place,(DataType)$3.type), rt);
            char *t = new_temp();
            tac_append(tac_new(TAC_ADD, t, l.place, r.place));
            $$.place = t; $$.type = rt;
        }
    | add_expr MINUS mul_expr
        {
            DataType rt = ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
            Expr l = coerce(make_expr($1.place,(DataType)$1.type), rt);
            Expr r = coerce(make_expr($3.place,(DataType)$3.type), rt);
            char *t = new_temp();
            tac_append(tac_new(TAC_SUB, t, l.place, r.place));
            $$.place = t; $$.type = rt;
        }
    | mul_expr  { $$ = $1; }
    ;

mul_expr
    : mul_expr STAR    unary_expr
        {
            DataType rt = ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
            char *t = new_temp();
            tac_append(tac_new(TAC_MUL, t, $1.place, $3.place));
            $$.place = t; $$.type = rt;
        }
    | mul_expr SLASH   unary_expr
        {
            DataType rt = ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
            char *t = new_temp();
            tac_append(tac_new(TAC_DIV, t, $1.place, $3.place));
            $$.place = t; $$.type = rt;
        }
    | mul_expr PERCENT unary_expr
        {
            char *t = new_temp();
            tac_append(tac_new(TAC_MOD, t, $1.place, $3.place));
            $$.place = t; $$.type = TYPE_INT;
        }
    | unary_expr  { $$ = $1; }
    ;

unary_expr
    : MINUS postfix_expr %prec UMINUS
        {
            char *t = new_temp();
            tac_append(tac_new(TAC_UMINUS, t, $2.place, NULL));
            $$.place = t; $$.type = $2.type;
        }
    | NOT postfix_expr
        {
            char *t = new_temp();
            tac_append(tac_new(TAC_NOT, t, $2.place, NULL));
            $$.place = t; $$.type = TYPE_INT;
        }
    | postfix_expr  { $$ = $1; }
    ;

postfix_expr
    : IDENTIFIER LPAREN arg_list_ne RPAREN
        {
            /* Function call */
            Symbol *fs = sym_lookup($1);
            if (!fs || fs->kind != KIND_FUNC) {
                fprintf(stderr, "Semantic error: '%s' is not a function\n", $1);
                exit(1);
            }
            char count_buf[16];
            snprintf(count_buf, sizeof(count_buf), "%d", fs->param_count);
            if (fs->type != TYPE_VOID) {
                char *t = new_temp();
                tac_append(tac_new(TAC_CALL, t, $1, count_buf));
                $$.place = t; $$.type = fs->type;
            } else {
                tac_append(tac_new(TAC_CALL, "", $1, count_buf));
                $$.place = strdup_safe("0"); $$.type = TYPE_INT;
            }
            free($1); free($3);
        }
    | IDENTIFIER LPAREN RPAREN
        {
            Symbol *fs = sym_lookup($1);
            if (!fs || fs->kind != KIND_FUNC) {
                fprintf(stderr, "Semantic error: '%s' is not a function\n", $1);
                exit(1);
            }
            if (fs->type != TYPE_VOID) {
                char *t = new_temp();
                tac_append(tac_new(TAC_CALL, t, $1, "0"));
                $$.place = t; $$.type = fs->type;
            } else {
                tac_append(tac_new(TAC_CALL, "", $1, "0"));
                $$.place = strdup_safe("0"); $$.type = TYPE_INT;
            }
            free($1);
        }
    | primary_expr  { $$ = $1; }
    ;

/* Argument list: emit PARAM instructions and return count as string */
arg_list_ne
    : expr
        {
            tac_append(tac_new(TAC_PARAM, NULL, $1.place, NULL));
            $$ = strdup_safe("1");
        }
    | arg_list_ne COMMA expr
        {
            tac_append(tac_new(TAC_PARAM, NULL, $3.place, NULL));
            /* increment count */
            int cnt = atoi($1) + 1;
            char buf[16]; snprintf(buf, sizeof(buf), "%d", cnt);
            free($1);
            $$ = strdup_safe(buf);
        }
    ;

primary_expr
    : IDENTIFIER
        {
            Symbol *s = sym_lookup($1);
            if (!s) {
                fprintf(stderr, "Semantic error (line ~%d): undeclared identifier '%s'\n",
                        yylineno, $1);
                exit(1);
            }
            $$.place = strdup_safe($1);
            $$.type  = s->type;
            free($1);
        }
    | INT_LITERAL
        {
            $$.place = strdup_safe($1);
            $$.type  = TYPE_INT;
            free($1);
        }
    | FLOAT_LITERAL
        {
            $$.place = strdup_safe($1);
            $$.type  = TYPE_FLOAT;
            free($1);
        }
    | CHAR_LITERAL
        {
            $$.place = strdup_safe($1);
            $$.type  = TYPE_CHAR;
            free($1);
        }
    | LPAREN expr RPAREN
        {
            $$ = $2;
        }
    ;

type_spec
    : KW_INT    { $$ = TYPE_INT;   }
    | KW_FLOAT  { $$ = TYPE_FLOAT; }
    | KW_CHAR   { $$ = TYPE_CHAR;  }
    | KW_VOID   { $$ = TYPE_VOID;  }
    ;

%%

void yyerror(const char *msg) {
    fprintf(stderr, "Syntax error (line %d): %s\n", yylineno, msg);
    exit(1);
}
