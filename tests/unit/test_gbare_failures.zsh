#!/usr/bin/env zsh
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"
oneTimeSetUp() { source "${SCRIPT_DIR}/gbare.zsh"; }
setUp() {
  source "${SCRIPT_DIR}/lib/helpers.zsh"
  _gbare_check_ssh() { return 0; }
  mkdir -p "${_TEST_TMPDIR}/local/.git"
  cd "${_TEST_TMPDIR}/local"
  : > "${_TEST_TMPDIR}/calls"
}
tearDown() { unfunction git 2>/dev/null; }

test_existence_transport_failure_stops_callers() {
  _gbare_ssh() { print -r -- 'transport diagnostic' >&2; return 255; }
  local command_name output result
  for command_name in clone delete info remote create; do
    output=$(_gbare_${command_name} example -y 2>&1)
    result=$?
    assertEquals 1 "$result" "$command_name fails"
    assertContains "$output" 'transport diagnostic' "$command_name preserves diagnostic"
    assertContains "$output" 'Failed to check repository' "$command_name identifies check failure"
    assertFalse "$command_name does not claim absence" '[[ "$output" == *"does not exist"* ]]'
  done
}

test_existence_negative_and_success_statuses() {
  local result expected
  for expected in 0 1 255; do
    _gbare_ssh() { return $expected; }
    _gbare_check_repo_exists example
    result=$?
    assertEquals "$expected" "$result" 'Preserves remote/SSH status'
  done
}

test_ssh_check_preserves_diagnostic() {
  source "${SCRIPT_DIR}/lib/helpers.zsh"
  _gbare_ssh() { print -r -- 'connection timed out' >&2; return 255; }
  local output result
  output=$(_gbare_check_ssh 2> "${_TEST_TMPDIR}/stderr")
  result=$?
  assertEquals 1 "$result" 'SSH check fails'
  assertEquals '' "$output" 'No diagnostic on stdout'
  output=$(<"${_TEST_TMPDIR}/stderr")
  assertContains "$output" 'connection timed out' 'Captured diagnostic on stderr'
  assertContains "$output" 'Troubleshooting:' 'Troubleshooting retained'
}

test_create_stops_after_local_init_failure() {
  _gbare_check_repo_exists() { return 1; }
  _gbare_ssh() { return 0; }
  git() { print -r -- "$*" >> "${_TEST_TMPDIR}/calls"; return 1; }
  mkdir -p "${_TEST_TMPDIR}/uninitialized"
  cd "${_TEST_TMPDIR}/uninitialized"
  local output result
  output=$(_gbare_create example -y 2>&1)
  result=$?
  assertEquals 1 "$result" 'Local init failure fails create'
  assertContains "$output" 'Remote repository exists' 'Explains remote state'
  assertContains "$output" 'local setup failed' 'Explains local failure'
  assertEquals init "$(<"${_TEST_TMPDIR}/calls")" 'No remote setup after init failure'
  unfunction _gbare_check_repo_exists
}

test_sync_uses_pulled_branch() {
  local chosen output result calls
  for chosen in main master neither; do
    : > "${_TEST_TMPDIR}/calls"
    git() {
      print -r -- "$*" >> "${_TEST_TMPDIR}/calls"
      case $1 in
        remote) print origin ;;
        pull) [[ $3 == "$chosen" ]] ;;
        push) return 0 ;;
      esac
    }
    output=$(_gbare_sync example 2>&1)
    result=$?
    calls=$(<"${_TEST_TMPDIR}/calls")
    if [[ $chosen == neither ]]; then
      assertEquals 1 "$result" 'Both pulls failing fails sync'
      assertFalse 'Does not push after pull failure' '[[ "$calls" == *push* ]]'
    else
      assertEquals 0 "$result" "$chosen sync succeeds"
      assertContains "$calls" "push origin HEAD:$chosen" 'Push uses pulled branch'
      if [[ $chosen == master ]]; then
        assertFalse 'Does not create main' '[[ "$calls" == *"HEAD:main"* ]]'
      fi
    fi
  done
}

test_backup_enumeration_failure() {
  _gbare_ssh() { print -r -- 'enumeration diagnostic' >&2; return 255; }
  local output result
  output=$(_gbare_backup "${_TEST_TMPDIR}/backup" 2>&1)
  result=$?
  assertEquals 1 "$result" 'Enumeration failure fails backup'
  assertContains "$output" 'enumeration diagnostic' 'Preserves stderr'
  assertFalse 'Does not report empty backup' '[[ "$output" == *"No repositories"* ]]'
}

test_backup_continues_and_aggregates_failures() {
  _gbare_ssh() { print -rl -- /repos/first.git /repos/second.git; }
  local clone_result output result calls
  for clone_result in 1 0; do
    : > "${_TEST_TMPDIR}/calls"
    git() {
      print -r -- "$*" >> "${_TEST_TMPDIR}/calls"
      if [[ $* == *first.git* ]]; then return $clone_result; fi
      return 0
    }
    output=$(_gbare_backup "${_TEST_TMPDIR}/backup" 2>&1)
    result=$?
    assertEquals "$clone_result" "$result" 'Aggregates clone outcomes'
    calls=$(<"${_TEST_TMPDIR}/calls")
    assertContains "$calls" 'second.git' 'Processes remaining repositories'
    if [[ $clone_result -eq 1 ]]; then
      assertContains "$output" 'Backup incomplete' 'Reports partial failure'
      assertFalse 'No completion claim on failure' '[[ "$output" == *"Backup completed"* ]]'
    else
      assertContains "$output" 'Backup completed' 'Reports complete success'
    fi
  done
  _gbare_ssh() { return 0; }
  output=$(_gbare_backup "${_TEST_TMPDIR}/backup")
  assertContains "$output" 'No repositories found' 'Empty successful enumeration retained'
}

test_search_literal_queries() {
  _gbare_ssh() { print -rl -- /repos/Ab.C.git /repos/abxc.git /repos/-Option.git /repos/bracket\[.git; }
  local output
  output=$(_gbare_search 'b.c')
  assertContains "$output" '• Ab.C' 'Case insensitive literal match'
  assertFalse 'Dot is not regex wildcard' '[[ "$output" == *"• abxc"* ]]'
  output=$(_gbare_search '-option')
  assertContains "$output" '• -Option' 'Leading hyphen is literal'
  output=$(_gbare_search '[')
  assertContains "$output" '• bracket[' 'Bracket is literal'
}
runAllTests
exit $?
