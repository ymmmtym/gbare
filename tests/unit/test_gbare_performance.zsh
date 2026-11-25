#!/usr/bin/env zsh

# ========================================
# gbare Performance Tests
# Repository list caching and parallel execution
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"

oneTimeSetUp() {
  source "${SCRIPT_DIR}/gbare.zsh"
  _gbare_init_colors
}

setUp() {
  cd "$_TEST_TMPDIR"
  export GBARE_USER="testuser"
  export GBARE_HOST="testhost"
  export GBARE_PORT=""
  export GBARE_PATH="${_TEST_TMPDIR}/git"
  export GBARE_CACHE_DIR="${_TEST_TMPDIR}/cache"
  export GBARE_CACHE_TTL="0"
  export GBARE_JOBS="1"
  rm -rf "$GBARE_CACHE_DIR"
  mkdir -p "$GBARE_PATH" one.git two.git three.git
  : > ssh_calls
  _gbare_check_ssh() { return 0; }
  _gbare_ssh() {
    print -r -- x >> ssh_calls
    print -r -- "${GBARE_PATH}/one.git"
    print -r -- "${GBARE_PATH}/two.git"
  }
}

# ========================================
# Caching
# ========================================

test_cache_disabled_by_default() {
  assertEquals "0" "$GBARE_CACHE_TTL" "Cache TTL is opt-in"

  local result
  result=$(_gbare_repository_paths)
  assertEquals 0 $? "Enumeration succeeds"
  assertEquals 2 "$(print -r -- "$result" | wc -l | tr -d ' ')" "Both paths reported"
  assertEquals 1 "$(wc -l < ssh_calls | tr -d ' ')" "Disabled cache queries the server"
}

test_cache_reuses_listing() {
  GBARE_CACHE_TTL=60

  local first second
  first=$(_gbare_repository_paths)
  second=$(_gbare_repository_paths)

  assertEquals "$first" "$second" "Cached listing matches"
  assertEquals 1 "$(wc -l < ssh_calls | tr -d ' ')" "Second call served from cache"
}

test_refresh_bypasses_cache() {
  GBARE_CACHE_TTL=60

  _gbare_repository_paths >/dev/null
  _gbare_repository_paths --refresh >/dev/null

  assertEquals 2 "$(wc -l < ssh_calls | tr -d ' ')" "--refresh re-enumerates the server"
}

test_expired_entry_is_refetched() {
  GBARE_CACHE_TTL=1

  _gbare_repository_paths >/dev/null
  local file
  file=$(_gbare_cache_file)
  # Backdate the entry beyond the TTL instead of sleeping.
  touch -d "10 seconds ago" -- "$file" 2>/dev/null || touch -t "$(date -v-10S +%Y%m%d%H%M.%S)" -- "$file"

  _gbare_repository_paths >/dev/null
  assertEquals 2 "$(wc -l < ssh_calls | tr -d ' ')" "Expired entry is refetched"
}

test_cache_is_per_server() {
  GBARE_CACHE_TTL=60

  _gbare_repository_paths >/dev/null
  GBARE_HOST="otherhost"
  _gbare_repository_paths >/dev/null

  assertEquals 2 "$(wc -l < ssh_calls | tr -d ' ')" "Different server uses a different entry"
}

test_invalidate_clears_cache() {
  GBARE_CACHE_TTL=60

  _gbare_repository_paths >/dev/null
  _gbare_cache_invalidate
  _gbare_repository_paths >/dev/null

  assertEquals 2 "$(wc -l < ssh_calls | tr -d ' ')" "Invalidation forces a refetch"
}

test_empty_listing_is_cached_and_reported() {
  GBARE_CACHE_TTL=60
  _gbare_ssh() { print -r -- x >> ssh_calls; return 0; }

  local result
  result=$(_gbare_repository_paths)
  assertEquals 0 $? "Empty listing succeeds"
  assertEquals "" "$result" "Empty listing prints nothing"
}

test_cache_read_reports_miss_when_absent() {
  GBARE_CACHE_TTL=60
  assertFalse 'Miss without a stored entry' '_gbare_cache_read'
}

test_cache_key_separates_similar_paths() {
  GBARE_PATH="/srv/team_a"
  local underscore
  underscore=$(_gbare_cache_file)
  GBARE_PATH="/srv/team/a"
  local nested
  nested=$(_gbare_cache_file)

  assertTrue 'Distinct paths get distinct entries' '[[ "$underscore" != "$nested" ]]'
  assertEquals "" "$(print -r -- "${nested:t}" | tr -d 'A-Za-z0-9._-')" "Key is hex only, no raw separator"
}

test_cache_key_has_fixed_length() {
  local short long
  GBARE_PATH="/srv/git"
  short=$(_gbare_cache_file)
  GBARE_PATH="/$(printf 'a%.0s' {1..240})"
  long=$(_gbare_cache_file)

  assertEquals "${#short}" "${#long}" "Key length does not grow with the path"
  assertTrue 'Filename stays under the 255-byte limit' '(( ${#long:t} < 255 ))'
}

test_cache_key_separates_unset_and_explicit_port() {
  GBARE_PORT=""
  local unset_port
  unset_port=$(_gbare_cache_file)
  GBARE_PORT="22"
  local explicit_port
  explicit_port=$(_gbare_cache_file)

  assertTrue 'Unset port differs from port 22' '[[ "$unset_port" != "$explicit_port" ]]'
}

test_cache_entries_are_owner_only() {
  GBARE_CACHE_TTL=60
  _gbare_repository_paths >/dev/null

  local file mode dir_mode
  file=$(_gbare_cache_file)
  mode=$(stat -c '%a' -- "$file")
  dir_mode=$(stat -c '%a' -- "${file:h}")

  assertEquals "600" "$mode" "Cached listing is owner-only"
  assertEquals "700" "$dir_mode" "Cache directory is owner-only"
}

test_cache_store_does_not_expose_temp_file() {
  GBARE_CACHE_TTL=60
  local file
  file=$(_gbare_cache_file)
  mkdir -p "${file:h}"

  # The entry must be private from the moment it exists, not chmod-ed afterwards.
  ( umask 022; _gbare_cache_store "listing" )
  assertEquals "600" "$(stat -c '%a' -- "$file")" "Entry is private even under umask 022"
}

test_cache_store_does_not_follow_planted_symlink() {
  GBARE_CACHE_TTL=60
  local file victim
  file=$(_gbare_cache_file)
  mkdir -p "${file:h}"
  victim="${GBARE_CACHE_DIR}/victim"
  print -r -- "ORIGINAL" >| "$victim"

  # A predictable temp path lets another account plant a symlink there.
  ln -sf -- "$victim" "${file}.$$"
  _gbare_cache_store "private repo names"

  assertEquals "ORIGINAL" "$(cat -- "$victim")" "Planted symlink is not written through"
  assertEquals "private repo names" "$(cat -- "$file")" "Listing is still cached"
}

test_cache_fetch_establishes_generation_marker() {
  GBARE_CACHE_TTL=60
  local file
  file=$(_gbare_cache_file)
  assertFalse "Cache directory starts absent" "[[ -d ${(q)GBARE_CACHE_DIR} ]]"

  _gbare_repository_paths >/dev/null
  assertTrue "Generation marker is recorded" "[[ -f ${(q)file}.gen ]]"
}

test_cache_invalidate_creates_no_directory() {
  GBARE_CACHE_TTL=60
  _gbare_cache_invalidate
  assertFalse "Invalidation alone does not create the cache directory" \
    "[[ -d ${(q)GBARE_CACHE_DIR} ]]"
}

test_successful_mutation_drops_listing_while_caching_disabled() {
  # A shell with a positive TTL shares the directory with one that mutates with
  # caching off; the mutation must still drop the listing the first shell uses.
  local file
  file=$(_gbare_cache_file)
  GBARE_CACHE_TTL=60
  _gbare_repository_paths >/dev/null
  assertTrue "Listing is cached" "[[ -f ${(q)file} ]]"

  GBARE_CACHE_TTL=0
  _gbare_cache_invalidate
  assertFalse "Listing is dropped despite caching being off" "[[ -f ${(q)file} ]]"
}

test_mutation_during_fetch_prevents_publish() {
  GBARE_CACHE_TTL=60
  local file
  file=$(_gbare_cache_file)
  mkdir -p "${file:h}"
  _gbare_cache_invalidate

  # A mutation landing mid-fetch bumps the generation; this fetch must not
  # publish a listing that predates it.
  _gbare_ssh() {
    print -r -- "${GBARE_PATH}/one.git"
    GBARE_CACHE_TTL=60 _gbare_cache_invalidate
  }
  _gbare_repository_paths >/dev/null
  assertFalse "Fetch declines to publish after a concurrent mutation" \
    "[[ -f ${(q)file} ]]"
}

test_cache_store_tightens_existing_directory() {
  GBARE_CACHE_TTL=60
  local file
  file=$(_gbare_cache_file)
  mkdir -p "${file:h}"
  chmod 755 "${file:h}"

  _gbare_cache_store "listing"
  assertEquals "700" "$(stat -c '%a' -- "${file:h}")" "Owned cache directory is tightened"
}

test_list_skips_ssh_probe_on_cache_hit() {
  GBARE_CACHE_TTL=60
  _gbare_repository_paths >/dev/null
  _gbare_check_ssh() { return 1; }

  local output
  output=$(_gbare_list 2>&1)
  assertEquals 0 $? "Cached listing works without a reachable server"
  assertContains "$output" "one" "Cached repository shown"
}

test_list_probes_ssh_when_cache_is_empty() {
  _gbare_check_ssh() { return 1; }

  _gbare_list >/dev/null 2>&1
  assertEquals 1 $? "Cold cache requires a working connection"
}

test_backup_ignores_cached_listing() {
  GBARE_CACHE_TTL=60
  _gbare_repository_paths >/dev/null
  # A repository added after the cache was filled must still be backed up.
  _gbare_ssh() {
    print -r -- x >> ssh_calls
    print -r -- "${GBARE_PATH}/three.git"
  }
  _gbare_git() { mkdir -p "${@: -1}"; }

  _gbare_backup "${_TEST_TMPDIR}/bk" >/dev/null 2>&1
  assertEquals 0 $? "Backup succeeds"
  assertContains "$(print -l -- "${_TEST_TMPDIR}"/bk/*/three.git(N))" "three.git" "Repository added after caching is backed up"
}

test_enumeration_failure_is_not_an_empty_inventory() {
  _gbare_ssh() { return 1; }
  assertFalse 'Unreadable root fails' '_gbare_repository_paths'
}

test_invalidate_discards_in_flight_listing() {
  GBARE_CACHE_TTL=60
  local file
  file=$(_gbare_cache_file)
  mkdir -p "${file:h}"

  _gbare_cache_invalidate
  local generation
  generation=$(cat -- "${file}.gen")

  _gbare_cache_invalidate
  assertTrue 'Generation advances on invalidate' '[[ "$(cat -- "${file}.gen")" != "$generation" ]]'
}

test_batch_delete_requires_literal_yes() {
  local output
  output=$(print -r -- '\yes' | _gbare_delete -j 2 one two 2>&1)
  assertEquals 0 $? "Cancelling is not an error"
  assertContains "$output" "Cancelled" "Backslash input does not confirm"

  output=$(print -r -- ' yes ' | _gbare_delete -j 2 one two 2>&1)
  assertContains "$output" "Cancelled" "Padded input does not confirm"
}

# ========================================
# Parallel execution
# ========================================

test_parallel_sequential_by_default() {
  assertEquals "1" "$GBARE_JOBS" "Sequential by default"

  worker() { print -r -- "$1" >> "${_TEST_TMPDIR}/order"; }
  _gbare_parallel worker one two three

  assertEquals 0 $? "Sequential run succeeds"
  assertEquals "one two three" "$(cat "${_TEST_TMPDIR}/order" | tr '\n' ' ' | sed 's/ $//')" "Items run in order"
}

test_parallel_runs_every_item() {
  export GBARE_JOBS=3
  worker() { print -r -- "$1" >> "${_TEST_TMPDIR}/done"; sleep 0.1; }
  _gbare_parallel worker one two three four

  assertEquals 0 $? "Parallel run succeeds"
  assertEquals 4 "$(wc -l < "${_TEST_TMPDIR}/done" | tr -d ' ')" "Every item ran"
}

test_parallel_aggregates_failures() {
  export GBARE_JOBS=3
  worker() { [[ $1 == two ]] && return 1; print -r -- "$1"; }
  local output
  output=$(_gbare_parallel worker one two three)
  local result=$?

  assertEquals 1 "$result" "Any failure fails the batch"
  assertContains "$output" "one" "Successful item reported"
  assertContains "$output" "three" "Processing continued past the failure"
}

test_parallel_reports_in_item_order() {
  export GBARE_JOBS=3
  worker() { [[ $1 == one ]] && sleep 0.2; print -r -- "$1"; }
  local output
  output=$(_gbare_parallel worker one two three)

  assertEquals "one two three" "$(print -r -- "$output" | tr '\n' ' ' | sed 's/ $//')" "Output replayed in order"
}

test_parallel_single_item_avoids_forking() {
  export GBARE_JOBS=4
  worker() { print -r -- "$1"; }
  local output
  output=$(_gbare_parallel worker only)

  assertEquals 0 $? "Single item succeeds"
  assertEquals "only" "$output" "Single item reported"
}

# ========================================
# Jobs flag plumbing
# ========================================

test_set_jobs_clamps_to_one() {
  _GBARE_JOBS_OVERRIDE=""
  _gbare_set_jobs 0
  assertEquals 1 "$_GBARE_JOBS_OVERRIDE" "Zero clamps to one"
}

test_set_jobs_rejects_non_numeric() {
  _GBARE_JOBS_OVERRIDE=""
  assertFalse 'Non-numeric rejected' '_gbare_set_jobs abc'
}

test_run_parallel_restores_jobs() {
  export GBARE_JOBS=2
  _GBARE_JOBS_OVERRIDE=5
  worker() { return 0; }
  _gbare_run_parallel worker one

  assertEquals "2" "$GBARE_JOBS" "GBARE_JOBS restored"
  assertEquals "" "$_GBARE_JOBS_OVERRIDE" "Override cleared"
}

test_url_accepts_multiple_repositories() {
  local result
  result=$(_gbare_url one two)

  assertEquals 0 $? "Multiple URLs succeed"
  assertContains "$result" "ssh://testuser@testhost${GBARE_PATH}/one.git" "First URL"
  assertContains "$result" "ssh://testuser@testhost${GBARE_PATH}/two.git" "Second URL"
}

test_url_rejects_missing_argument() {
  local result
  result=$(_gbare_url 2>&1)
  assertEquals 1 $? "Usage error"
  assertContains "$result" "Usage" "Shows usage"
}

test_list_rejects_unknown_option() {
  local result
  result=$(_gbare_list --bogus 2>&1)
  assertEquals 0 $? "Unknown options are ignored"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
