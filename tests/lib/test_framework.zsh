#!/usr/bin/env zsh

# ========================================
# Simple Test Framework for zsh
# ========================================

autoload -U colors && colors

# テスト統計
_TEST_COUNT=0
_TEST_PASSED=0
_TEST_FAILED=0
_CURRENT_TEST=""
_TEST_TMPDIR=""

# アサーション関数
assertEquals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"
  
  _TEST_COUNT=$((_TEST_COUNT + 1))
  
  if [[ "$expected" == "$actual" ]]; then
    _TEST_PASSED=$((_TEST_PASSED + 1))
    echo "${fg[green]}  ✓${reset_color} ${_CURRENT_TEST}: ${message}"
  else
    _TEST_FAILED=$((_TEST_FAILED + 1))
    echo "${fg[red]}  ✗${reset_color} ${_CURRENT_TEST}: ${message}"
    echo "    Expected: ${expected}"
    echo "    Actual:   ${actual}"
  fi
}

assertContains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"
  
  _TEST_COUNT=$((_TEST_COUNT + 1))
  
  if [[ "$haystack" == *"$needle"* ]]; then
    _TEST_PASSED=$((_TEST_PASSED + 1))
    echo "${fg[green]}  ✓${reset_color} ${_CURRENT_TEST}: ${message}"
  else
    _TEST_FAILED=$((_TEST_FAILED + 1))
    echo "${fg[red]}  ✗${reset_color} ${_CURRENT_TEST}: ${message}"
    echo "    String not found: ${needle}"
    echo "    In: ${haystack}"
  fi
}

assertTrue() {
  local message="$1"
  local condition="$2"
  
  _TEST_COUNT=$((_TEST_COUNT + 1))
  
  if eval "$condition"; then
    _TEST_PASSED=$((_TEST_PASSED + 1))
    echo "${fg[green]}  ✓${reset_color} ${_CURRENT_TEST}: ${message}"
  else
    _TEST_FAILED=$((_TEST_FAILED + 1))
    echo "${fg[red]}  ✗${reset_color} ${_CURRENT_TEST}: ${message}"
  fi
}

assertFalse() {
  local message="$1"
  local condition="$2"
  
  _TEST_COUNT=$((_TEST_COUNT + 1))
  
  if ! eval "$condition"; then
    _TEST_PASSED=$((_TEST_PASSED + 1))
    echo "${fg[green]}  ✓${reset_color} ${_CURRENT_TEST}: ${message}"
  else
    _TEST_FAILED=$((_TEST_FAILED + 1))
    echo "${fg[red]}  ✗${reset_color} ${_CURRENT_TEST}: ${message}"
  fi
}

# テスト実行
runTest() {
  local test_name="$1"
  _CURRENT_TEST="$test_name"
  
  # setUp があれば実行
  if typeset -f setUp > /dev/null; then
    setUp
  fi
  
  # テスト実行
  $test_name
  
  # tearDown があれば実行
  if typeset -f tearDown > /dev/null; then
    tearDown
  fi
}

# テスト結果表示
showResults() {
  echo ""
  echo "${fg[cyan]}========================================${reset_color}"
  echo "Tests run: ${_TEST_COUNT}"
  echo "${fg[green]}Passed: ${_TEST_PASSED}${reset_color}"
  
  if [[ $_TEST_FAILED -gt 0 ]]; then
    echo "${fg[red]}Failed: ${_TEST_FAILED}${reset_color}"
    return 1
  else
    echo "${fg[green]}All tests passed!${reset_color}"
    return 0
  fi
}

# すべてのテスト関数を実行
runAllTests() {
  # 一時ディレクトリを作成
  _TEST_TMPDIR=$(mktemp -d)
  cd "$_TEST_TMPDIR"
  
  # oneTimeSetUp があれば実行
  if typeset -f oneTimeSetUp > /dev/null; then
    oneTimeSetUp
  fi
  
  # test_ で始まる関数を実行
  for test_func in ${(k)functions}; do
    if [[ "$test_func" == test_* ]]; then
      runTest "$test_func"
    fi
  done
  
  # oneTimeTearDown があれば実行
  if typeset -f oneTimeTearDown > /dev/null; then
    oneTimeTearDown
  fi
  
  # 一時ディレクトリを削除
  cd /
  [[ -n "$_TEST_TMPDIR" ]] && rm -rf "$_TEST_TMPDIR"
  
  showResults
}
