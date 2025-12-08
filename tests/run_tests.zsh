#!/usr/bin/env zsh

autoload -U colors && colors

echo "${fg[cyan]}========================================${reset_color}"
echo "${fg[cyan]}Running gbare Unit Tests${reset_color}"
echo "${fg[cyan]}========================================${reset_color}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/unit"

FAILED=0
TOTAL=0
for test_file in ${TEST_DIR}/test_*.zsh; do
  if [[ -f "$test_file" ]]; then
    TOTAL=$((TOTAL + 1))
    echo "${fg[yellow]}Running: $(basename $test_file)${reset_color}"
    zsh "$test_file"
    if [[ $? -ne 0 ]]; then
      FAILED=$((FAILED + 1))
    fi
    echo ""
  fi
done

echo "${fg[cyan]}========================================${reset_color}"
if [[ $FAILED -eq 0 ]]; then
  echo "${fg[green]}All ${TOTAL} test file(s) passed!${reset_color}"
  exit 0
else
  echo "${fg[red]}${FAILED}/${TOTAL} test file(s) failed${reset_color}"
  exit 1
fi
