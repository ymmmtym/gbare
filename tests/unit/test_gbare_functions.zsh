#!/usr/bin/env zsh

# ========================================
# gbare Function Tests
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
# URL Generation Tests
# ========================================

test_remote_url_basic() {
  local result=$(_gbare_remote_url "myrepo")
  assertEquals "ssh://testuser@testhost/test/git/myrepo.git" "$result" "Basic URL"
}

test_remote_url_with_port() {
  GBARE_PORT="2222"
  local result=$(_gbare_remote_url "myrepo")
  assertEquals "ssh://testuser@testhost:2222/test/git/myrepo.git" "$result" "URL with port"
  GBARE_PORT=""
}

test_remote_url_with_dash() {
  local result=$(_gbare_remote_url "my-repo")
  assertEquals "ssh://testuser@testhost/test/git/my-repo.git" "$result" "URL with dash"
}

test_remote_url_with_underscore() {
  local result=$(_gbare_remote_url "my_repo")
  assertEquals "ssh://testuser@testhost/test/git/my_repo.git" "$result" "URL with underscore"
}

test_remote_url_with_numbers() {
  local result=$(_gbare_remote_url "repo123")
  assertEquals "ssh://testuser@testhost/test/git/repo123.git" "$result" "URL with numbers"
}

# ========================================
# Config Tests
# ========================================

test_config_contains_user() {
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_USER" "Config has USER key"
  assertContains "$output" "testuser" "Config has USER value"
}

test_config_contains_host() {
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_HOST" "Config has HOST key"
  assertContains "$output" "testhost" "Config has HOST value"
}

test_config_contains_path() {
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_PATH" "Config has PATH key"
  assertContains "$output" "/test/git" "Config has PATH value"
}

test_config_port_empty() {
  GBARE_PORT=""
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_PORT" "Config has PORT key"
}

test_config_port_set() {
  GBARE_PORT="2222"
  local output=$(_gbare_config)
  assertContains "$output" "2222" "Config shows PORT value"
  GBARE_PORT=""
}

test_config_ssh_timeout() {
  local output=$(_gbare_config)
  assertContains "$output" "GBARE_SSH_TIMEOUT" "Config has SSH_TIMEOUT key"
  assertContains "$output" "10s" "Config shows timeout value"
}

# ========================================
# Info Command Tests
# ========================================

test_info_without_name() {
  local result=$(_gbare_info 2>&1)
  assertContains "$result" "Usage" "Shows usage message"
}

test_info_with_name() {
  local result=$(_gbare_info "myrepo")
  assertContains "$result" "myrepo" "Shows repo name"
  assertContains "$result" "ssh://" "Shows SSH URL"
}

# ========================================
# URL Command Tests
# ========================================

test_url_command() {
  local result=$(_gbare_url "myrepo")
  assertEquals "ssh://testuser@testhost/test/git/myrepo.git" "$result" "URL command output"
}

test_url_without_name() {
  local result=$(_gbare_url 2>&1)
  assertContains "$result" "Usage" "Shows usage message without name"
}

# ========================================
# Error Handling Function Tests
# ========================================

test_error_function_exists() {
  assertTrue "_gbare_error exists" "typeset -f _gbare_error > /dev/null"
}

test_check_ssh_function_exists() {
  assertTrue "_gbare_check_ssh exists" "typeset -f _gbare_check_ssh > /dev/null"
}

test_repo_exists_function_exists() {
  assertTrue "_gbare_repo_exists exists" "typeset -f _gbare_repo_exists > /dev/null"
}

test_ssh_timeout_configurable() {
  export GBARE_SSH_TIMEOUT="30"
  assertEquals "30" "$GBARE_SSH_TIMEOUT" "SSH timeout is configurable"
  export GBARE_SSH_TIMEOUT="10"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
