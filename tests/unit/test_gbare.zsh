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
  assertContains "$output" "GBARE_COLOR" "Config contains GBARE_COLOR"
}

test_gbare_config_values() {
  local output=$(_gbare_config)
  assertContains "$output" "testuser" "Config shows correct user"
  assertContains "$output" "testhost" "Config shows correct host"
  assertContains "$output" "/test/git" "Config shows correct path"
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
