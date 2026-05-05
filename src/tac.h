#ifndef TAC_H
#define TAC_H

/* TAC opcodes */
typedef enum {
    TAC_ASSIGN,     /* x = y         */
    TAC_ADD,        /* x = y + z     */
    TAC_SUB,        /* x = y - z     */
    TAC_MUL,        /* x = y * z     */
    TAC_DIV,        /* x = y / z     */
    TAC_MOD,        /* x = y % z     */
    TAC_UMINUS,     /* x = -y        */
    TAC_LT,         /* x = y < z     */
    TAC_LE,         /* x = y <= z    */
    TAC_GT,         /* x = y > z     */
    TAC_GE,         /* x = y >= z    */
    TAC_EQ,         /* x = y == z    */
    TAC_NE,         /* x = y != z    */
    TAC_AND,        /* x = y && z    */
    TAC_OR,         /* x = y || z    */
    TAC_NOT,        /* x = !y        */
    TAC_LABEL,      /* L:            */
    TAC_GOTO,       /* goto L        */
    TAC_IF_FALSE,   /* if !x goto L  */
    TAC_IF_TRUE,    /* if  x goto L  */
    TAC_CALL,       /* x = call f, n */
    TAC_PARAM,      /* param x       */
    TAC_RETURN,     /* return x      */
    TAC_RETURN_VOID,/* return        */
    TAC_FUNC_BEGIN, /* func_begin f  */
    TAC_FUNC_END,   /* func_end f    */
    TAC_CAST        /* x = (type) y  */
} TacOp;

typedef struct TacInstr {
    TacOp op;
    char *result;   /* destination / label name */
    char *arg1;
    char *arg2;
    struct TacInstr *next;
} TacInstr;

/* TAC list management */
TacInstr *tac_new(TacOp op, const char *result, const char *arg1, const char *arg2);
void      tac_append(TacInstr *instr);
void      tac_print_all(void);
TacInstr *tac_head(void);

/* Helpers */
char *new_temp(void);          /* allocates t0, t1, t2 … */
char *new_label(void);         /* allocates L0, L1, L2 … */
char *strdup_safe(const char *s);

#endif
