#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tac.h"

/* ---------- list head ---------- */
static TacInstr *head = NULL;
static TacInstr *tail = NULL;

/* ---------- counters ---------- */
static int temp_count  = 0;
static int label_count = 0;

/* ---------- helpers ---------- */
char *strdup_safe(const char *s) {
    if (!s) return NULL;
    char *p = (char *)malloc(strlen(s) + 1);
    if (!p) { perror("malloc"); exit(1); }
    strcpy(p, s);
    return p;
}

char *new_temp(void) {
    char buf[32];
    snprintf(buf, sizeof(buf), "t%d", temp_count++);
    return strdup_safe(buf);
}

char *new_label(void) {
    char buf[32];
    snprintf(buf, sizeof(buf), "L%d", label_count++);
    return strdup_safe(buf);
}

/* ---------- instruction creation ---------- */
TacInstr *tac_new(TacOp op, const char *result, const char *arg1, const char *arg2) {
    TacInstr *i = (TacInstr *)calloc(1, sizeof(TacInstr));
    i->op     = op;
    i->result = strdup_safe(result);
    i->arg1   = strdup_safe(arg1);
    i->arg2   = strdup_safe(arg2);
    i->next   = NULL;
    return i;
}

void tac_append(TacInstr *instr) {
    if (!instr) return;
    if (!head) { head = tail = instr; }
    else       { tail->next = instr; tail = instr; }
}

TacInstr *tac_head(void) { return head; }

/* ---------- pretty-printer ---------- */
static const char *op_symbol(TacOp op) {
    switch (op) {
        case TAC_ADD: return "+";
        case TAC_SUB: return "-";
        case TAC_MUL: return "*";
        case TAC_DIV: return "/";
        case TAC_MOD: return "%";
        case TAC_LT:  return "<";
        case TAC_LE:  return "<=";
        case TAC_GT:  return ">";
        case TAC_GE:  return ">=";
        case TAC_EQ:  return "==";
        case TAC_NE:  return "!=";
        case TAC_AND: return "&&";
        case TAC_OR:  return "||";
        default: return "?";
    }
}

void tac_print_all(void) {
    printf("\n========== Three Address Code (TAC) ==========\n");
    for (TacInstr *i = head; i; i = i->next) {
        switch (i->op) {
            case TAC_ASSIGN:
                printf("    %s = %s\n", i->result, i->arg1);
                break;
            case TAC_ADD: case TAC_SUB: case TAC_MUL:
            case TAC_DIV: case TAC_MOD:
            case TAC_LT:  case TAC_LE:  case TAC_GT:
            case TAC_GE:  case TAC_EQ:  case TAC_NE:
            case TAC_AND: case TAC_OR:
                printf("    %s = %s %s %s\n",
                       i->result, i->arg1, op_symbol(i->op), i->arg2);
                break;
            case TAC_UMINUS:
                printf("    %s = -%s\n", i->result, i->arg1);
                break;
            case TAC_NOT:
                printf("    %s = !%s\n", i->result, i->arg1);
                break;
            case TAC_CAST:
                printf("    %s = (cast) %s\n", i->result, i->arg1);
                break;
            case TAC_LABEL:
                printf("%s:\n", i->result);
                break;
            case TAC_GOTO:
                printf("    goto %s\n", i->result);
                break;
            case TAC_IF_FALSE:
                printf("    if_false %s goto %s\n", i->arg1, i->result);
                break;
            case TAC_IF_TRUE:
                printf("    if_true %s goto %s\n", i->arg1, i->result);
                break;
            case TAC_PARAM:
                printf("    param %s\n", i->arg1);
                break;
            case TAC_CALL:
                if (i->result && strlen(i->result) > 0)
                    printf("    %s = call %s, %s\n", i->result, i->arg1, i->arg2);
                else
                    printf("    call %s, %s\n", i->arg1, i->arg2);
                break;
            case TAC_RETURN:
                printf("    return %s\n", i->arg1 ? i->arg1 : "");
                break;
            case TAC_RETURN_VOID:
                printf("    return\n");
                break;
            case TAC_FUNC_BEGIN:
                printf("\nfunc_begin %s\n", i->result);
                break;
            case TAC_FUNC_END:
                printf("func_end %s\n", i->result);
                break;
            default:
                printf("    [unknown tac op %d]\n", i->op);
        }
    }
    printf("==============================================\n");
}
