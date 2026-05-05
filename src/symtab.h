#ifndef SYMTAB_H
#define SYMTAB_H

#define MAX_SYMBOLS 512
#define MAX_SCOPE_DEPTH 64
#define MAX_NAME_LEN 64

typedef enum {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_CHAR,
    TYPE_VOID,
    TYPE_UNKNOWN
} DataType;

typedef enum {
    KIND_VAR,
    KIND_FUNC,
    KIND_PARAM
} SymKind;

typedef struct Symbol {
    char name[MAX_NAME_LEN];
    DataType type;
    SymKind kind;
    int scope_level;
    int is_defined;      /* for functions: has body been seen */
    int param_count;     /* for functions */
    DataType param_types[16];
    struct Symbol *next; /* chaining in hash bucket */
} Symbol;

/* Scope stack */
void scope_push(void);
void scope_pop(void);
int  scope_current(void);

/* Symbol operations */
Symbol *sym_insert(const char *name, DataType type, SymKind kind);
Symbol *sym_lookup(const char *name);          /* searches all scopes */
Symbol *sym_lookup_current(const char *name);  /* only current scope  */

/* Utility */
const char *type_name(DataType t);
void symtab_dump(void);

#endif
