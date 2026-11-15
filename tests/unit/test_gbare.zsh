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

# Exercise SSH argument boundaries without a network connection.
test_gbare_ssh_arguments() {
  local GBARE_SSH_TIMEOUT=7
  local GBARE_PORT
  local expected_options=$'-o\nLogLevel=ERROR\n-o\nConnectTimeout=7\n-o\nServerAliveInterval=5\n-o\nServerAliveCountMax=2'
  local result

  for GBARE_PORT in "" 2222; do
    result=$(
      ssh() { print -rl -- "$@"; }
      _gbare_ssh "echo 'hello world'"
    )
    local expected="$expected_options"
    if [[ -n "$GBARE_PORT" ]]; then
      expected+=$'\n-p\n2222'
    fi
    expected+=$'\ntestuser@testhost\necho \'hello world\''
    assertEquals "$expected" "$result" "SSH argument boundaries (port: ${GBARE_PORT:-default})"
  done

  (
    ssh() { return 255; }
    _gbare_ssh "echo OK"
  )
  assertEquals 255 "$?" "SSH failure status is preserved"
}

test_gbare_list_empty_and_missing_directory() {
  local GBARE_PATH="$_TEST_TMPDIR/empty-repos"
  mkdir -p "$GBARE_PATH"
  local result
  result=$(
    _gbare_ssh() { sh -c "$1"; }
    _gbare_check_ssh() { return 0; }
    _gbare_list 2>&1
  )
  assertEquals 0 "$?" "Empty repository directory succeeds"
  assertContains "$result" "No repositories found" "Empty listing is explained"
  rmdir "$GBARE_PATH"
  result=$(
    _gbare_ssh() { sh -c "$1"; }
    _gbare_check_ssh() { return 0; }
    _gbare_list 2>&1
  )
  assertEquals 1 "$?" "Missing repository directory fails"
  assertContains "$result" "Failed to list repositories" "Listing errors are reported"
}

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
  assertContains "$output" "GBARE_COLOR" "Config contains GBARE_COLOR"
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
# Color Support Tests
# ========================================

test_gbare_color_enabled() {
  GBARE_COLOR="true"
  source "${SCRIPT_DIR}/gbare.zsh"
  assertNotEquals "" "$GBARE_COLOR_GREEN" "Color should be enabled"
}

test_gbare_color_disabled() {
  GBARE_COLOR="false"
  source "${SCRIPT_DIR}/gbare.zsh"
  assertEquals "" "$GBARE_COLOR_GREEN" "Color should be disabled when GBARE_COLOR=false"
}

# ========================================
# Search Tests
# ========================================

test_gbare_search_usage() {
  local output=$(_gbare_search 2>&1)
  assertContains "$output" "Usage" "Search shows usage when no query"
}

# ========================================
# Sync Tests
# ========================================

test_gbare_sync_usage() {
  # sync should work with current directory name if no arg
  # Just test it doesn't crash with no args in a non-git dir
  cd /tmp
  local output=$(_gbare_sync 2>&1)
  assertContains "$output" "Not a git repository" "Sync fails in non-git dir"
  cd "${SCRIPT_DIR}"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
