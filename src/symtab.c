#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"

/* ---------- scope stack ---------- */
static int scope_stack[MAX_SCOPE_DEPTH];
static int scope_top = 0;
static int next_scope_id = 0;

void scope_push(void) {
    if (scope_top >= MAX_SCOPE_DEPTH - 1) {
        fprintf(stderr, "Internal error: scope stack overflow\n");
        exit(1);
    }
    scope_stack[++scope_top] = ++next_scope_id;
}

void scope_pop(void) {
    if (scope_top <= 0) {
        fprintf(stderr, "Internal error: scope stack underflow\n");
        exit(1);
    }
    scope_top--;
}

int scope_current(void) {
    return scope_stack[scope_top];
}

/* ---------- hash table ---------- */
#define HASH_SIZE 256

static Symbol *table[HASH_SIZE];

static unsigned int hash(const char *name) {
    unsigned int h = 0;
    while (*name) h = h * 31 + (unsigned char)*name++;
    return h % HASH_SIZE;
}

Symbol *sym_insert(const char *name, DataType type, SymKind kind) {
    unsigned int h = hash(name);
    Symbol *s = (Symbol *)calloc(1, sizeof(Symbol));
    strncpy(s->name, name, MAX_NAME_LEN - 1);
    s->type = type;
    s->kind = kind;
    s->scope_level = scope_current();
    s->is_defined = 0;
    s->param_count = 0;
    /* prepend – newest declaration found first */
    s->next = table[h];
    table[h] = s;
    return s;
}

Symbol *sym_lookup(const char *name) {
    unsigned int h = hash(name);
    /* Walk chain; return innermost (highest scope id reached first) */
    Symbol *best = NULL;
    for (Symbol *s = table[h]; s; s = s->next) {
        if (strcmp(s->name, name) == 0) {
            /* Check that scope is visible: it must be one of the scopes
               currently on the stack */
            for (int i = scope_top; i >= 0; i--) {
                if (scope_stack[i] == s->scope_level) {
                    if (!best || s->scope_level > best->scope_level)
                        best = s;
                    break;
                }
            }
        }
    }
    return best;
}

Symbol *sym_lookup_current(const char *name) {
    unsigned int h = hash(name);
    int cur = scope_current();
    for (Symbol *s = table[h]; s; s = s->next) {
        if (strcmp(s->name, name) == 0 && s->scope_level == cur)
            return s;
    }
    return NULL;
}

/* ---------- utility ---------- */
const char *type_name(DataType t) {
    switch (t) {
        case TYPE_INT:   return "int";
        case TYPE_FLOAT: return "float";
        case TYPE_CHAR:  return "char";
        case TYPE_VOID:  return "void";
        default:         return "unknown";
    }
}

void symtab_dump(void) {
    printf("\n=== Symbol Table Dump ===\n");
    for (int i = 0; i < HASH_SIZE; i++) {
        for (Symbol *s = table[i]; s; s = s->next) {
            printf("  %-20s  type=%-7s  kind=%-6s  scope=%d\n",
                   s->name,
                   type_name(s->type),
                   s->kind == KIND_VAR  ? "var"   :
                   s->kind == KIND_FUNC ? "func"  : "param",
                   s->scope_level);
        }
    }
    printf("=========================\n\n");
}
