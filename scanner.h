#pragma once

typedef enum {
  TOKEN_REGISTER,
  TOKEN_INTEGER,
  TOKEN_MOV,
  TOKEN_NOT,
  TOKEN_OR,
  TOKEN_ADD,
  TOKEN_SUB,
  TOKEN_NAND,
  TOKEN_AND,
  TOKEN_XOR,
  TOKEN_EQ,
  TOKEN_COMMA,
  TOKEN_LEFT_BRACKET,
  TOKEN_RIGHT_BRACKET,
  TOKEN_EOF,
} TokenType;

typedef struct {
  TokenType type;
  int value;
  char *source;
  int length;
  int line;
} Token;

Token tokens[10000];

void init_scanner(char *file_name);

void scan_tokens();

