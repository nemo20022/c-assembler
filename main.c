#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "scanner.h"
#include "parser.h"

static void print_usage(const char *program) {
  fprintf(stderr, "Usage: %s [-f input-file] | %s [input-file]\n", program, program);
}

int main(int argc, char *argv[]) {
  char *input_file = "example.asm";
  int i;
  int filename_selected = 0;

  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-f") == 0) {
      if (filename_selected) {
        fprintf(stderr, "Multiple input filenames were provided.\n");
        print_usage(argv[0]);
        return EXIT_FAILURE;
      }
      if (i + 1 >= argc || argv[i + 1][0] == '-') {
        fprintf(stderr, "Missing filename after -f.\n");
        print_usage(argv[0]);
        return EXIT_FAILURE;
      }
      input_file = argv[++i];
      filename_selected = 1;
    } else if (argv[i][0] == '-') {
      fprintf(stderr, "Unknown option '%s'.\n", argv[i]);
      print_usage(argv[0]);
      return EXIT_FAILURE;
    } else {
      if (filename_selected) {
        fprintf(stderr, "Multiple input filenames were provided.\n");
        print_usage(argv[0]);
        return EXIT_FAILURE;
      }
      input_file = argv[i];
      filename_selected = 1;
    }
  }

  init_scanner(input_file);
  scan_tokens();
  parse_lines();
  print_binary();
  return 0;
}
