# Compiler Project

A C-based compiler that performs **lexical analysis**, **parsing**, **semantic analysis**, and **Three-Address Code (TAC) generation** for a C-like language. Built using **Flex** and **Bison**.

---

## Features

- **Lexer** — Tokenizes keywords, identifiers, literals, operators, and comments
- **Parser** — Validates syntax and drives semantic checks via a Bison grammar
- **Symbol Table** — Tracks variable/function declarations with scoped lookups
- **Semantic Analysis** — Type checking, implicit int→float widening, and error reporting
- **TAC Generation** — Produces Three-Address Code for arithmetic, control flow, function calls, and casts

### Supported Language Constructs

- Data types: `int`, `float`, `char`, `void`
- Operators: arithmetic (`+`, `-`, `*`, `/`, `%`), relational (`==`, `!=`, `<`, `>`, `<=`, `>=`), logical (`&&`, `||`, `!`)
- Control flow: `if/else`, `while`, `for`
- Functions: declarations, calls, and `return`
- Single-line (`//`) and block (`/* */`) comments

---

## Project Structure

```
compiler_project/
├── src/
│   ├── lexer.l        # Flex lexer
│   ├── parser.y       # Bison parser + semantic actions
│   ├── symtab.c/h     # Symbol table
│   ├── tac.c/h        # Three-Address Code generation
│   └── main.c         # Entry point
├── tests/
│   ├── test1_arithmetic.c
│   ├── test2_control_flow.c
│   └── test3_functions.c
└── Makefile
```

---

## Dependencies

- `gcc`
- `flex`
- `bison`

Install on Ubuntu/Debian:
```bash
sudo apt install gcc flex bison
```

---

## Build & Run

```bash
# Build
make

# Compile a source file
./compiler <source_file.c>

# Compile and dump the symbol table
./compiler <source_file.c> --symtab

# Run all tests
make test

# Clean build artifacts
make clean
```

---

## Example Output

```
=== Compiling: tests/test1_arithmetic.c ===
Parsing and semantic analysis: OK

=== Three-Address Code ===
t0 = a + b
t1 = a - b
...
```

---

## Author

**Muhammad Irfan** — [@mirfan723](https://github.com/mirfan723)
