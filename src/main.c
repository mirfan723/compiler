#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"
#include "tac.h"

extern int yyparse(void);
extern FILE *yyin;
extern int yylineno;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <source_file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "r");
    if (!f) {
        perror(argv[1]);
        return 1;
    }

    printf("=== Compiling: %s ===\n", argv[1]);

    /* Initialize: push global scope (scope 0) */
    scope_push();

    yyin = f;
    int result = yyparse();
    fclose(f);

    if (result != 0) {
        fprintf(stderr, "Compilation failed.\n");
        return 1;
    }

    printf("Parsing and semantic analysis: OK\n");

    /* Print generated TAC */
    tac_print_all();

    /* Optionally dump symbol table */
    if (argc >= 3 && strcmp(argv[2], "--symtab") == 0) {
        symtab_dump();
    }

    return 0;
}
