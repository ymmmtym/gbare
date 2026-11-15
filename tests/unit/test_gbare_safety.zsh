#!/usr/bin/env zsh
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"
oneTimeSetUp() {
  source "${SCRIPT_DIR}/lib/helpers.zsh"
  source "${SCRIPT_DIR}/lib/core.zsh"
}
setUp() {
  cd "$_TEST_TMPDIR"
  rm -rf .git
  : > calls
  GBARE_PATH="$_TEST_TMPDIR/remote ' space"
  GBARE_USER=test GBARE_HOST=test GBARE_PORT=''
  inventory='' ssh_result=0 init_result=0 clone_result=0 pull_branch=main
  _gbare_ssh() { print -r -- "$inventory"; return $ssh_result; }
  git() {
    print -r -- "$*" >> "$_TEST_TMPDIR/calls"
    case $1 in
      init) return $init_result ;;
      remote) [[ $# == 1 ]] && echo origin; return 0 ;;
      pull) [[ $3 == $pull_branch ]] ;;
      clone) return $clone_result ;;
      *) return 0 ;;
    esac
  }
}
test_remote_paths() {
  # Execute generated commands with a POSIX shell and real Git/filesystem.
  _gbare_ssh() { sh -c "$1"; }
  mkdir -p "$GBARE_PATH" .git
  local name='space '\''; touch INJECTED; $(touch SUBSTITUTED)'
  _gbare_create "$name" -y >/dev/null 2>&1
  assertEquals 0 $? 'create succeeds'
  assertTrue 'one literal repository path' '[[ -d "$GBARE_PATH/$name.git" ]]'
  assertFalse 'no command injection' '[[ -e INJECTED || -e SUBSTITUTED ]]'
  _gbare_info "$name" >/dev/null
  _gbare_delete "$name" <<< "$name" >/dev/null
  assertEquals 0 $? 'delete succeeds'
  assertFalse 'literal repository removed' '[[ -e "$GBARE_PATH/$name.git" ]]'
}
test_invalid_names() {
  local name operation
  _gbare_ssh() { echo called >> calls; }
  for name in ../escape nested/name . .. $'line\nbreak'; do
    for operation in create delete info; do
      _gbare_$operation "$name" -y </dev/null >/dev/null 2>&1
      assertEquals 1 $? "$operation rejects invalid name"
    done
  done
  assertEquals '' "$(cat calls)" 'no remote calls'
}
test_init_failure() {
  init_result=1
  local output
  output=$(_gbare_create repo -y)
  assertEquals 1 $? 'init failure propagates'
  assertFalse 'no local success' '[[ $output == *"Local repository initialized"* ]]'
  assertEquals init "$(cat calls)" 'no remote add after init failure'
}
test_init_success() {
  _gbare_create repo -y >/dev/null
  assertEquals 0 $? 'create succeeds'
  assertContains "$(cat calls)" 'remote add origin' 'remote added after init'
}
test_sync_branch() {
  mkdir .git
  local branch result
  for branch in main master missing; do
    : > calls
    pull_branch=$branch
    _gbare_sync repo >/dev/null
    result=$?
    if [[ $branch == missing ]]; then
      assertEquals 1 $result 'failed pulls fail sync'
      assertFalse 'no push after failed pulls' '[[ $(cat calls) == *push* ]]'
    else
      assertEquals 0 $result 'sync succeeds'
      assertContains "$(cat calls)" "push origin HEAD:$branch" 'push follows pull'
      assertEquals 1 "$(grep -c '^push ' calls)" 'one push only'
    fi
  done
}
test_backup_status() {
  local output
  ssh_result=255
  output=$(_gbare_backup backups)
  assertEquals 1 $? 'SSH failure propagates'
  assertFalse 'failure is not empty inventory' '[[ $output == *"No repositories"* ]]'
  ssh_result=0
  output=$(_gbare_backup backups)
  assertEquals 0 $? 'empty inventory succeeds'
  assertContains "$output" 'No repositories' 'empty message'
  inventory=$'./first repo.git\n./second.git'
  clone_result=1
  output=$(_gbare_backup backups)
  assertEquals 1 $? 'clone failures propagate'
  assertFalse 'no completion on failure' '[[ $output == *"Backup completed"* ]]'
  assertEquals 2 "$(grep -c '^clone ' calls)" 'tries every repository'
  clone_result=0
  output=$(_gbare_backup backups)
  assertEquals 0 $? 'all clones succeed'
  assertContains "$output" 'Backup completed' 'completion on success'
}
test_inventory_command() {
  _gbare_ssh() { sh -c "$1"; }
  mkdir -p "$GBARE_PATH"
  _gbare_backup backups >/dev/null
  assertEquals 0 $? 'real empty directory succeeds'
  mkdir -p "$GBARE_PATH/one space.git"
  _gbare_backup backups >/dev/null
  assertEquals 0 $? 'inventory with spaces succeeds'
  assertContains "$(cat calls)" 'one space.git' 'repository enumerated'
  GBARE_PATH="$_TEST_TMPDIR/nonexistent"
  _gbare_backup backups >/dev/null
  assertEquals 1 $? 'missing directory fails'
}
test_literal_search() {
  inventory=$'/git/Foo.Bar.git\n/git/fooXbar.git\n/git/-option.git\n/git/[bracket].git'
  local output query
  for query in FOO.BAR -option '['; do
    output=$(_gbare_search "$query")
    assertFalse 'literal query matches' '[[ $output == *"No repositories matching"* ]]'
  done
  output=$(_gbare_search FOO.BAR)
  assertContains "$output" '• Foo.Bar' 'case insensitive match'
  assertFalse 'dot is literal' '[[ $output == *"• fooXbar"* ]]'
}
runAllTests
exit $?
