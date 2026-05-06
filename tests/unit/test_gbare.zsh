#!/usr/bin/env zsh

# ========================================
# gbare Unit Tests
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"

oneTimeSetUp() {
  source "${SCRIPT_DIR}/gbare.zsh"
  
  export GBARE_USER="testuser"
  export GBARE_HOST="testhost"
  export GBARE_PORT=""
  export GBARE_PATH="/test/git"
  export GBARE_SSH_TIMEOUT="10"
}

# ========================================
# Helper Function Tests
# ========================================

test_gbare_remote_url_without_port() {
  GBARE_PORT=""
  local result=$(_gbare_remote_url "myrepo")
  assertEquals "ssh://testuser@testhost/test/git/myrepo.git" "$result" "URL without port"
}

test_gbare_remote_url_with_port() {
  GBARE_PORT="2222"
  local result=$(_gbare_remote_url "myrepo")
  assertEquals "ssh://testuser@testhost:2222/test/git/myrepo.git" "$result" "URL with port"
  GBARE_PORT=""
}

test_gbare_remote_url_special_chars() {
  local result=$(_gbare_remote_url "my-repo_123")
  assertEquals "ssh://testuser@testhost/test/git/my-repo_123.git" "$result" "URL with special chars"
}

# ========================================
# Config Tests
# ========================================

test_gbare_config_output() {
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_USER" "Config contains GBARE_USER"
  assertContains "$output" "GBARE_HOST" "Config contains GBARE_HOST"
  assertContains "$output" "GBARE_PATH" "Config contains GBARE_PATH"
  assertContains "$output" "GBARE_SSH_TIMEOUT" "Config contains GBARE_SSH_TIMEOUT"
}

test_gbare_config_values() {
  local output=$(_gbare_config)
  assertContains "$output" "testuser" "Config shows correct user"
  assertContains "$output" "testhost" "Config shows correct host"
  assertContains "$output" "/test/git" "Config shows correct path"
  assertContains "$output" "10s" "Config shows timeout value"
}

# ========================================
# Error Handling Tests
# ========================================

test_gbare_error_function_exists() {
  assertTrue "_gbare_error function exists" "typeset -f _gbare_error > /dev/null"
}

test_gbare_error_outputs_to_stderr() {
  local output
  output=$(_gbare_error "test error message" 2>&1 >/dev/null)
  assertContains "$output" "test error message" "Error message contains test text"
}

test_gbare_error_format() {
  local output
  output=$(_gbare_error "something failed" 2>&1 >/dev/null)
  assertContains "$output" "ERROR" "Error output contains ERROR label"
  assertContains "$output" "something failed" "Error output contains message"
}

test_gbare_check_ssh_function_exists() {
  assertTrue "_gbare_check_ssh function exists" "typeset -f _gbare_check_ssh > /dev/null"
}

test_gbare_repo_exists_function_exists() {
  assertTrue "_gbare_repo_exists function exists" "typeset -f _gbare_repo_exists > /dev/null"
}

test_gbare_ssh_timeout_default() {
  assertEquals "10" "$GBARE_SSH_TIMEOUT" "Default SSH timeout is 10 seconds"
}

# ========================================
# Info Command Tests
# ========================================

test_gbare_info_without_name() {
  local result=$(_gbare_info 2>&1)
  assertContains "$result" "Usage" "Shows usage message"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
