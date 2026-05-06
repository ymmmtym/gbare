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
}

test_gbare_config_timeout_default() {
  local output=$(_gbare_config)
  assertContains "$output" "10s" "Config shows default timeout"
}

test_gbare_error_function() {
  local output=$(_gbare_error "test error message" 2>&1)
  assertContains "$output" "test error message" "Error function outputs message"
}

test_gbare_warn_function() {
  local output=$(_gbare_warn "test warning message")
  assertContains "$output" "test warning message" "Warn function outputs message"
}

test_gbare_ok_function() {
  local output=$(_gbare_ok "test success message")
  assertContains "$output" "test success message" "OK function outputs message"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
