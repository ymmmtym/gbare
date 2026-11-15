#!/usr/bin/env zsh
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"
oneTimeSetUp() {
  source "${SCRIPT_DIR}/gbare.plugin.zsh"
  GBARE_COLOR=false
  _gbare_init_colors
  GBARE_HOST=testhost
}
setUp() {
  mkdir -p "$_TEST_TMPDIR/work"
  cd "$_TEST_TMPDIR/work"
  rm -rf .git
}

test_remote_paths_are_shell_arguments() {
  (
    GBARE_PATH="$_TEST_TMPDIR/remote path's;literal"
    local name='repo $(touch INJECTED); *'
    mkdir -p "$GBARE_PATH"
    _gbare_ssh() { [[ $1 == -n ]] && shift; sh -c "$1"; }
    git() { return 0; }
    _gbare_create "$name" -y >/dev/null
    assertTrue 'Remote init used literal path' '[[ -d "$GBARE_PATH/$name.git" ]]'
    assertFalse 'No command substitution executed' '[[ -e INJECTED ]]'
    local output
    output=$(_gbare_repository_paths)
    assertEquals "$GBARE_PATH/$name.git" "$output" 'Enumeration quotes base path'
    local object_id=$(print test | command git -C "$GBARE_PATH/$name.git" hash-object -w --stdin)
    command git -C "$GBARE_PATH/$name.git" update-ref refs/tags/check "$object_id"
    output=$(_gbare_info "$name")
    assertContains "$output" "$object_id refs/tags/check" 'Info enters literal repository path' 
    _gbare_delete "$name" <<< "$name" >/dev/null
    assertFalse 'Delete used literal path' '[[ -d "$GBARE_PATH/$name.git" ]]'
    output=$(_gbare_repository_paths)
    assertEquals '' "$output" 'Empty directory succeeds'
    # Return assertions to the parent through the subshell exit status.
    (( _TEST_FAILED == 0 ))
  )
  assertEquals 0 $? 'Remote shell quoting checks'
}

test_loaders_reject_old_versions() {
  local loader output result
  for loader in gbare.plugin.zsh gbare.zsh lib/config.zsh; do
    output=$(ZSH_VERSION=4.3.1; source "$SCRIPT_DIR/$loader" 2>&1); result=$?
    assertEquals 1 "$result" "$loader rejects old zsh"
    assertContains "$output" 'requires zsh 5.0' 'Actionable minimum version'
  done
}

test_create_local_failures() {
  _gbare_check_repo_exists() { return 1; }
  _gbare_ssh() { return 0; }
  git() { return 1; }
  local output result
  output=$(_gbare_create test -y); result=$?
  assertEquals 1 "$result" 'Failed init propagates'
  assertFalse 'No init success message' '[[ "$output" == *"Local repository initialized"* ]]'
  mkdir .git
  output=$(_gbare_create test -y); result=$?
  assertEquals 1 "$result" 'Failed remote add propagates'
  assertContains "$output" 'Failed to add remote' 'Accurate error'
  unfunction git _gbare_check_repo_exists
}

test_enumeration_status() {
  local flow output result
  _gbare_ssh() { return 255; }
  for flow in _gbare_list _gbare_search _gbare_backup; do
    output=$($flow query 2>&1); result=$?
    assertEquals 1 "$result" "$flow propagates SSH failure"
    assertFalse 'No empty result message' '[[ "$output" == *"No repositories"* ]]'
  done
  _gbare_ssh() { return 0; }
  for flow in _gbare_list _gbare_search _gbare_backup; do
    output=$($flow query 2>&1); result=$?
    assertEquals 0 "$result" "$flow accepts successful empty output"
    assertContains "$output" 'No repositories' 'Empty result message'
  done
}

test_backup_partial_failure() {
  _gbare_ssh() { printf '/test/bad.git\n/test/good.git\n'; }
  git() {
    print -r -- "$*" >> "$_TEST_TMPDIR/clones"
    [[ "$*" != *bad.git* ]]
  }
  _gbare_backup "$_TEST_TMPDIR/backups" >/dev/null
  assertEquals 1 $? 'Partial failure propagates'
  assertContains "$(cat "$_TEST_TMPDIR/clones")" good.git 'Later repositories still processed'
  unfunction git
}

test_search_literal_queries() {
  _gbare_ssh() { printf '/test/a.b.git\n/test/axb.git\n/test/-Option.git\n/test/[bracket.git\n'; }
  local output
  output=$(_gbare_search A.B)
  assertContains "$output" '• a.b' 'Case insensitive literal match'
  assertFalse 'Dot is literal' '[[ "$output" == *"• axb"* ]]'
  output=$(_gbare_search -option)
  assertContains "$output" '• -Option' 'Leading hyphen is a pattern'
  output=$(_gbare_search '[bracket')
  assertContains "$output" '• [bracket' 'Bracket is literal'
  output=$(_gbare_search missing)
  assertContains "$output" 'No repositories matching' 'No match behavior'
}

test_sync_branch_selection() {
  mkdir .git
  local heads branch output result
  for branch in main master; do
    heads=$'hash\trefs/heads/'$branch
    git() {
      case "$1" in
        remote) print origin ;;
        ls-remote) print -r -- "$heads" ;;
        pull|push) print -r -- "$*" >> "$_TEST_TMPDIR/sync"; [[ "$1" != push ]] ;;
      esac
    }
    : > "$_TEST_TMPDIR/sync"
    output=$(_gbare_sync test); result=$?
    assertEquals 1 "$result" 'Push failure propagates'
    assertEquals "$(printf 'pull origin %s\npush origin HEAD:%s' "$branch" "$branch")" "$(cat "$_TEST_TMPDIR/sync")" 'Pull and push share branch without push retry'
  done
  unfunction git
}
runAllTests
exit $?
