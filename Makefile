CC      = gcc
CFLAGS  = -Wall -Wno-unused-function -g
SRCDIR  = src
OBJDIR  = obj

# Generated files
PARSER_C = $(SRCDIR)/parser.tab.c
PARSER_H = $(SRCDIR)/parser.tab.h
LEXER_C  = $(SRCDIR)/lex.yy.c

SRCS = $(PARSER_C) $(LEXER_C) $(SRCDIR)/symtab.c $(SRCDIR)/tac.c $(SRCDIR)/main.c
OBJS = $(OBJDIR)/parser.tab.o $(OBJDIR)/lex.yy.o \
       $(OBJDIR)/symtab.o $(OBJDIR)/tac.o $(OBJDIR)/main.o

TARGET = compiler

.PHONY: all clean test

all: $(OBJDIR) $(TARGET)

$(OBJDIR):
	mkdir -p $(OBJDIR)

# Bison: generate parser.tab.c and parser.tab.h
$(PARSER_C) $(PARSER_H): $(SRCDIR)/parser.y
	bison -d -o $(PARSER_C) $(SRCDIR)/parser.y

# Flex: generate lex.yy.c (depends on parser header for token defs)
$(LEXER_C): $(SRCDIR)/lexer.l $(PARSER_H)
	flex -o $(LEXER_C) $(SRCDIR)/lexer.l

# Compile rules
$(OBJDIR)/parser.tab.o: $(PARSER_C) $(PARSER_H)
	$(CC) $(CFLAGS) -I$(SRCDIR) -c $< -o $@

$(OBJDIR)/lex.yy.o: $(LEXER_C) $(PARSER_H)
	$(CC) $(CFLAGS) -I$(SRCDIR) -c $< -o $@

$(OBJDIR)/symtab.o: $(SRCDIR)/symtab.c $(SRCDIR)/symtab.h
	$(CC) $(CFLAGS) -I$(SRCDIR) -c $< -o $@

$(OBJDIR)/tac.o: $(SRCDIR)/tac.c $(SRCDIR)/tac.h
	$(CC) $(CFLAGS) -I$(SRCDIR) -c $< -o $@

$(OBJDIR)/main.o: $(SRCDIR)/main.c $(SRCDIR)/symtab.h $(SRCDIR)/tac.h
	$(CC) $(CFLAGS) -I$(SRCDIR) -c $< -o $@

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ -lfl

clean:
	rm -f $(PARSER_C) $(PARSER_H) $(LEXER_C)
	rm -rf $(OBJDIR)
	rm -f $(TARGET)

# Run all test cases
test: all
	@echo ""
	@echo "=============================="
	@echo " Test 1: arithmetic.c"
	@echo "=============================="
	./$(TARGET) tests/test1_arithmetic.c
	@echo ""
	@echo "=============================="
	@echo " Test 2: control_flow.c"
	@echo "=============================="
	./$(TARGET) tests/test2_control_flow.c
	@echo ""
	@echo "=============================="
	@echo " Test 3: functions.c"
	@echo "=============================="
	./$(TARGET) tests/test3_functions.c
