#!/usr/bin/env zsh
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"
oneTimeSetUp() { source "${SCRIPT_DIR}/gbare.zsh"; }
setUp() {
  source "${SCRIPT_DIR}/lib/helpers.zsh"
  _gbare_check_ssh() { return 0; }
}
tearDown() { unfunction git 2>/dev/null; }

test_remote_paths_are_literal() {
  local GBARE_PATH="${_TEST_TMPDIR}/repos ' ; \$(touch injected)"
  local repo_name="repo ' ; \$(touch injected)"
  mkdir -p "${GBARE_PATH}/${repo_name}.git"
  _gbare_ssh() { [[ $1 == -n ]] && shift; sh -c "$1"; }
  _gbare_check_repo_exists "$repo_name"
  assertEquals 0 "$?" 'Quoted path finds the intended directory'
  _gbare_check_repo_exists missing
  assertEquals 1 "$?" 'Negative test remains negative'
  assertFalse 'No injected command executed' '[[ -e injected ]]'
  local name
  for name in ../escape a/b . .. $'line\nbreak'; do
    _gbare_check_repo_exists "$name" 2>/dev/null
    assertEquals 2 "$?" 'Rejects names outside a single directory'
  done
}

test_remote_builders_handle_quoted_paths() {
  local GBARE_PATH="${_TEST_TMPDIR}/builders ' ; \$(literal)"
  local repo_name="project ' ; \$(literal)"
  mkdir -p "$GBARE_PATH" "${_TEST_TMPDIR}/work/.git"
  cd "${_TEST_TMPDIR}/work"
  _gbare_ssh() { [[ $1 == -n ]] && shift; sh -c "$1"; }
  git() { return 0; }
  local output result
  output=$(_gbare_create "$repo_name" -y 2>&1); result=$?
  assertEquals 0 "$result" 'Create handles quoted remote path'
  assertTrue 'Creates intended bare repository' '[[ -f "${GBARE_PATH}/${repo_name}.git/HEAD" ]]'
  output=$(_gbare_list 2>&1); result=$?
  assertEquals 0 "$result" 'List handles quoted base path'
  assertContains "$output" "$repo_name" 'Lists intended repository'
  output=$(_gbare_delete "$repo_name" <<< "$repo_name" 2>&1); result=$?
  assertEquals 0 "$result" 'Delete handles quoted path'
  assertFalse 'Intended repository removed' '[[ -e "${GBARE_PATH}/${repo_name}.git" ]]'
}

test_info_handles_empty_refs_and_failures() {
  local GBARE_PATH="${_TEST_TMPDIR}/info repos"
  mkdir -p "${GBARE_PATH}"
  command git init --bare "${GBARE_PATH}/empty.git" >/dev/null 2>&1
  _gbare_ssh() { [[ $1 == -n ]] && shift; sh -c "$1"; }
  local output result
  output=$(_gbare_info empty 2>&1); result=$?
  assertEquals 0 "$result" 'Empty Git repository succeeds'
  assertContains "$output" '(empty repository)' 'Explains empty references'
  _gbare_ssh() {
    [[ $1 == -n ]] && return 0
    print -r -- 'transport diagnostic' >&2
    return 255
  }
  output=$(_gbare_info empty 2>&1); result=$?
  assertEquals 1 "$result" 'Reference SSH failure fails info'
  assertContains "$output" 'transport diagnostic' 'Preserves transport details'
  assertFalse 'Failure is not empty repository' '[[ "$output" == *"(empty repository)"* ]]'
}

test_search_distinguishes_failure_from_empty() {
  local output result
  _gbare_ssh() { print -r -- diagnostic >&2; return 255; }
  output=$(_gbare_search example 2>&1); result=$?
  assertEquals 1 "$result" 'SSH enumeration failure fails search'
  assertContains "$output" diagnostic 'Preserves stderr'
  assertFalse 'Failure is not empty enumeration' '[[ "$output" == *"No repositories found"* ]]'
  _gbare_ssh() { return 0; }
  output=$(_gbare_search example 2>&1); result=$?
  assertEquals 0 "$result" 'Successful empty enumeration succeeds'
  assertContains "$output" 'No repositories found' 'Retains empty behavior'
}

test_git_transfers_share_ssh_options() {
  local GBARE_PORT=2222 GBARE_SSH_TIMEOUT=7
  git() { print -r -- "$GIT_SSH_COMMAND"; return 23; }
  local output result
  output=$(_gbare_git clone example); result=$?
  assertEquals 23 "$result" 'Git failure propagates'
  local -a args
  args=("${(@Q)${(z)output}}")
  assertEquals ssh "$args[1]" 'Uses SSH'
  assertContains "$output" ConnectTimeout=7 'Configured timeout'
  assertContains "$output" ServerAliveInterval=5 'Keepalive interval'
  assertContains "$output" ServerAliveCountMax=2 'Keepalive limit'
  assertContains "$output" 2222 'Configured port'
}
runAllTests
exit $?
