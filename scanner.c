#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "scanner.h"

void read_file(char *filename, char **buffer) {
  long length;
  FILE *f = fopen(filename, "rb");
  if (f == NULL) {
    exit(1);
  }
  fseek(f, 0, SEEK_END);
  length = ftell(f);
  fseek(f, 0, SEEK_SET);
  *buffer = malloc(length);
  if (buffer == NULL) {
    exit(2);
  }
  fread(*buffer, 1, length, f);
  fclose(f);
}

struct Scanner {
  char *start;
  char *current;
  int line;
} scanner;

void init_scanner(char *file_name) {
  char *file_content;
  read_file(file_name, &file_content);
  scanner.start = file_content;
  scanner.current = file_content;
  scanner.line = 1;
}

char peek_char() {
  return *scanner.current;
}

char consume_char() {
  char c = *scanner.current;
  scanner.current += 1;
  return c;
}

int get_scanner_length() {
  return (int)(scanner.current - scanner.start);
}

Token create_token(TokenType type, int value) {
  Token token;
  token.type = type;
  token.value = value;
  token.source = scanner.start;
  token.line = scanner.line;
  token.length = get_scanner_length();
  return token;
}

void consume_whitespace() {
  while (true) {
    char c = peek_char();
    if (c == ';') {
      while (peek_char() != '\n' && peek_char() != '\0')
        consume_char();
      continue;
    }
    if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
      return;
    if (c == '\n')
      scanner.line += 1;
    consume_char();
  }
}

bool is_digit(char c) {
  return c >= '0' && c <= '9';
}

bool is_alpha(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

bool is_alpha_numeric(char c) {
  return is_alpha(c) || is_digit(c);
}

Token create_int(char c) {
  int result = c - '0';
  while (is_digit(peek_char())) {
    c = consume_char();
    result = (result * 10) + (c - '0'); // append the digit c to result
  }
  return create_token(TOKEN_INTEGER, result);
}

bool is_token_equal_to(char* s) {
  int scan_len = get_scanner_length();
  if (scan_len != strlen(s))
    return false;
  for (int i=0; i<scan_len; i++)
    if (s[i] != scanner.start[i])
      return false;
  return true;
}

Token create_identifier() {
  while (is_alpha_numeric(peek_char())) {
    consume_char();
  }

  if (is_token_equal_to("mov"))
    return create_token(TOKEN_MOV, 0);
  if (is_token_equal_to("not"))
    return create_token(TOKEN_NOT, 0);
  if (is_token_equal_to("reg1"))
    return create_token(TOKEN_REGISTER, 1);
  if (is_token_equal_to("reg2"))
    return create_token(TOKEN_REGISTER, 2);
  if (is_token_equal_to("reg3"))
    return create_token(TOKEN_REGISTER, 3);
  if (is_token_equal_to("reg4"))
    return create_token(TOKEN_REGISTER, 4);
  if (is_token_equal_to("reg5"))
    return create_token(TOKEN_REGISTER, 5);
  if (is_token_equal_to("reg6"))
    return create_token(TOKEN_REGISTER, 6);

  printf("Compile error on line %d: unknown identifier.\n", scanner.line);
  exit(1);
}

Token scan_token() {
  consume_whitespace();

  scanner.start = scanner.current;
  char c = consume_char();

  if (c == ',')
    return create_token(TOKEN_COMMA, 0);
  if (is_digit(c))
    return create_int(c);
  if (is_alpha(c))
    return create_identifier();
  if (c == '\0')
    return create_token(TOKEN_EOF, 0);

  printf("Compile error on line %d: Unexpected character '%c'.\n", scanner.line, c);
  exit(1);
}

void scan_tokens() {
  for (int i=0; true; i++) {
    tokens[i] = scan_token();
    if (tokens[i].type == TOKEN_EOF)
      return;
  }
}
