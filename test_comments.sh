#!/bin/sh
set -eu

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

gcc -std=c11 -Wall -Wextra -Wpedantic -Werror main.c scanner.c parser.c -o "$tmp_dir/assembler"

printf '; full-line comment\nmov reg1, 10 ; inline comment\nmov reg2, reg1 ; comment at end of file' > "$tmp_dir/example.asm"
printf '\000' >> "$tmp_dir/example.asm"

printf '00001010\n10001010\n' > "$tmp_dir/expected"
(cd "$tmp_dir" && ./assembler) > "$tmp_dir/actual"

if ! cmp -s "$tmp_dir/expected" "$tmp_dir/actual"; then
  echo "FAIL: semicolon comments changed the assembled output." >&2
  diff -u "$tmp_dir/expected" "$tmp_dir/actual" >&2 || true
  exit 1
fi

echo "PASS: full-line, inline, and end-of-file semicolon comments"
