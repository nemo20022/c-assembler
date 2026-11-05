#!/bin/sh
set -eu

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

gcc -std=c11 -Wall -Wextra -Wpedantic -Werror main.c scanner.c parser.c -o "$tmp_dir/assembler"

printf '; Part 1 comment support remains active\nnot reg2, reg1 ; invert reg1 into reg2\n' > "$tmp_dir/example.asm"
printf '\000' >> "$tmp_dir/example.asm"
printf '01010101\n' > "$tmp_dir/expected"
(cd "$tmp_dir" && ./assembler) > "$tmp_dir/actual"

if ! cmp -s "$tmp_dir/expected" "$tmp_dir/actual"; then
  echo "FAIL: NOT instruction output did not match 01010101." >&2
  diff -u "$tmp_dir/expected" "$tmp_dir/actual" >&2 || true
  exit 1
fi
echo "PASS: not reg2, reg1 emits 01010101 and comments are ignored"

printf 'not reg2, reg3\n\000' > "$tmp_dir/example.asm"
if (cd "$tmp_dir" && ./assembler) > /dev/null 2>&1; then
  echo "FAIL: NOT with a non-reg1 source was accepted." >&2
  exit 1
fi
echo "PASS: NOT with an unsupported source register is rejected"

printf 'not reg2,\n\000' > "$tmp_dir/example.asm"
if (cd "$tmp_dir" && ./assembler) > /dev/null 2>&1; then
  echo "FAIL: NOT with a missing source was accepted." >&2
  exit 1
fi
echo "PASS: NOT with a missing source register is rejected"
