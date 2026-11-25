# ========================================
# Helper Functions
# ========================================

# Execute command on remote server via SSH
# Usage: _gbare_ssh <command>
# Args:
#   command - Shell command to execute on remote server
# Returns:
#   Exit status of remote command
_gbare_ssh_options() {
  ssh_opts=(
    -o LogLevel=ERROR
    -o "ConnectTimeout=${GBARE_SSH_TIMEOUT}"
    -o ServerAliveInterval=5
    -o ServerAliveCountMax=2
  )

  [[ -z "$GBARE_PORT" ]] || ssh_opts+=(-p "$GBARE_PORT")
}

_gbare_ssh() {
  local -a ssh_opts
  _gbare_ssh_options
  ssh "${ssh_opts[@]}" "${GBARE_USER}@${GBARE_HOST}" "$@"
}

# Git starts its own SSH process; use the same connection policy.
_gbare_git() {
  local -a ssh_opts
  _gbare_ssh_options
  GIT_SSH_COMMAND="ssh ${(j: :)${(@q)ssh_opts}}" GIT_SSH_VARIANT=ssh git "$@"
}

# Quote a complete argument for the remote POSIX shell.
_gbare_quote() {
  print -r -- "${(qq)1}"
}

# Names must identify one directory beneath GBARE_PATH.
_gbare_validate_repo_name() {
  if [[ -z "$1" || "$1" == . || "$1" == .. || "$1" == */* || "$1" == *[[:cntrl:]]* ]]; then
    _gbare_error "Invalid repository name"
    return 2
  fi
}

# SSH接続チェック
_gbare_check_ssh() {
  local output
  output=$(_gbare_ssh -n "echo OK" 2>&1)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "${GBARE_COLOR_RED}Error: SSH connection failed${GBARE_COLOR_RESET}" >&2
    [[ -n "$output" ]] && print -r -- "  Details: ${output}" >&2
    echo "  Host: ${GBARE_HOST}" >&2
    if [[ -n "$GBARE_PORT" ]]; then
      echo "  Port: ${GBARE_PORT}" >&2
    fi
    echo "  User: ${GBARE_USER}" >&2
    echo "" >&2
    echo "Troubleshooting:" >&2
    echo "  1. Check your network connection" >&2
    echo "  2. Verify SSH key is configured: ssh-add -l" >&2
    echo "  3. Test connection: ssh ${GBARE_USER}@${GBARE_HOST} 'echo test'" >&2
    if [[ $exit_code -eq 255 ]]; then
      echo "  4. Connection was refused or timed out" >&2
    fi
    return 1
  fi

  return 0
}

# リポジトリ存在チェック
# Returns: 0 if present, 1 if absent, other statuses on SSH/remote errors.
_gbare_check_repo_exists() {
  local repo_name=$1
  _gbare_validate_repo_name "$repo_name" || return $?
  _gbare_ssh -n "test -d $(_gbare_quote "${GBARE_PATH}/${repo_name}.git")"
  return $?
}

# エラーメッセージ表示
_gbare_error() {
  echo "${GBARE_COLOR_RED}Error: $1${GBARE_COLOR_RESET}" >&2
}

# 警告メッセージ表示
_gbare_warn() {
  echo "${GBARE_COLOR_YELLOW}Warning: $1${GBARE_COLOR_RESET}"
}

# 成功メッセージ表示
_gbare_ok() {
  echo "${GBARE_COLOR_GREEN}$1${GBARE_COLOR_RESET}"
}

# Build SSH URL for a remote repository
# Usage: _gbare_remote_url <repo_name>
_gbare_remote_url() {
  local repo_name=$1
  _gbare_validate_repo_name "$repo_name" || return $?
  if [[ -n "$GBARE_PORT" ]]; then
    echo "ssh://${GBARE_USER}@${GBARE_HOST}:${GBARE_PORT}${GBARE_PATH}/${repo_name}.git"
  else
    echo "ssh://${GBARE_USER}@${GBARE_HOST}${GBARE_PATH}/${repo_name}.git"
  fi
}


# ========================================
# Repository list cache
# ========================================

# Caching only pays off on high-latency links, and a stale list hides remote
# changes, so the lifetime stays short and callers can bypass it.
_gbare_cache_enabled() {
  [[ $GBARE_CACHE_TTL == <-> ]] && (( GBARE_CACHE_TTL > 0 ))
}

# One cache entry per server and path, so switching profiles never mixes lists.
# The key is a fixed-length FNV-1a digest: escaping the raw fields would let a
# long GBARE_PATH exceed the 255-byte filename limit, while hashing keeps every
# entry the same size. Hashing in zsh avoids depending on sha256sum/shasum, and
# the fields stay unambiguous because ":" cannot appear in the user, host or a
# numeric port, and an unset port is spelled out instead of defaulting to 22.
_gbare_cache_key() {
  emulate -L zsh
  local key="${GBARE_USER}@${GBARE_HOST}:${GBARE_PORT-<unset>}:${GBARE_PATH}"
  local hash=-3750763034362895579  # FNV-1a 64-bit basis as a signed literal
  local char
  for char in ${(s::)key}; do
    hash=$(( (hash ^ #char) * 1099511628211 ))
  done
  printf '%016x' $hash
}

_gbare_cache_file() {
  print -r -- "${GBARE_CACHE_DIR}/$(_gbare_cache_key).repos"
}

# Print the cached listing when the entry is younger than GBARE_CACHE_TTL.
# Returns 1 on a miss, which also covers a missing stat/datetime module.
_gbare_cache_read() {
  _gbare_cache_enabled || return 1

  local file
  file=$(_gbare_cache_file)
  [[ -f "$file" ]] || return 1

  zmodload -F zsh/stat b:zstat 2>/dev/null || return 1
  zmodload zsh/datetime 2>/dev/null || return 1

  local -a mtime
  zstat -A mtime +mtime -- "$file" 2>/dev/null || return 1
  (( EPOCHSECONDS - mtime[1] < GBARE_CACHE_TTL )) || return 1

  cat -- "$file"
}

# The listing holds private repository names, so the directory and the entry are
# created owner-only rather than inheriting a group/world-readable umask.
_gbare_cache_store() {
  _gbare_cache_enabled || return 0

  local file dir
  file=$(_gbare_cache_file)
  dir=${file:h}
  # An existing directory is tightened too, but only when we own it.
  if [[ -d "$dir" ]]; then
    [[ -O "$dir" ]] && chmod 700 -- "$dir" 2>/dev/null
  else
    mkdir -p -m 700 -- "$dir" 2>/dev/null || return 0
  fi

  # mktemp creates the file with O_EXCL, so a symlink planted at the predictable
  # "${file}.$$" path cannot redirect this write onto a file we can modify.
  local tmp
  tmp=$(mktemp -- "${file}.XXXXXX" 2>/dev/null) || return 0
  # umask 077 keeps the entry private from the instant it exists, instead of
  # chmod-ing it after a window where it is readable.
  if (umask 077 && print -r -- "$1" >| "$tmp") 2>/dev/null; then
    mv -f -- "$tmp" "$file" 2>/dev/null || rm -f -- "$tmp"
  else
    rm -f -- "$tmp"
  fi
  return 0
}

# Drop the cached listing; call after any change to the remote repository set.
# Bumping the stored generation also discards listings that were already in
# flight, so a slow fetch cannot republish what this call just invalidated.
_gbare_cache_invalidate() {
  local file
  file=$(_gbare_cache_file)
  # A shell that mutates without caching may still share GBARE_CACHE_DIR with one
  # that caches, so invalidate even when caching is disabled here. Nothing to
  # discard means nothing to do, and no directory is created for a cache miss.
  [[ -d "${file:h}" ]] || return 0

  zmodload zsh/datetime 2>/dev/null
  print -r -- "${EPOCHSECONDS}.${RANDOM}" >| "${file}.gen" 2>/dev/null
  rm -f -- "$file" 2>/dev/null
  return 0
}

# Emit repository paths, succeeding with no output for an empty directory.
# Usage: _gbare_repository_paths [--refresh]
# Args:
#   --refresh - Ignore the cached listing and re-enumerate the server
_gbare_repository_paths() {
  local use_cache=true
  if [[ $1 == --refresh ]]; then
    use_cache=false
    shift
  fi

  local listing
  if [[ $use_cache == true ]] && listing=$(_gbare_cache_read); then
    [[ -z "$listing" ]] || print -r -- "$listing"
    return 0
  fi

  local key file generation dir
  key=$(_gbare_cache_key)
  file="${GBARE_CACHE_DIR}/${key}.repos"
  dir=${file:h}

  # Establish the generation baseline before enumerating, so a mutation that
  # happens mid-fetch changes it and this fetch declines to publish. The marker
  # has to exist year-round: a mutating shell may run with caching disabled and
  # only bumps an existing marker rather than creating the directory itself.
  if [[ $use_cache == true ]]; then
    mkdir -p -m 700 -- "$dir" 2>/dev/null
    [[ -f "${file}.gen" ]] || _gbare_cache_invalidate
  fi
  generation=$(cat -- "${file}.gen" 2>/dev/null)

  # -H follows the configured root when it is itself a symlink, while children
  # stay unfollowed. find is used instead of a glob because the remote shell may
  # be zsh, where an unmatched *.git pattern is an error rather than empty.
  # Sorting happens locally: piping to sort on the remote would make the pipeline
  # status sort's, hiding a find failure as an empty inventory.
  if ! listing=$(_gbare_ssh "test -d ${(qq)GBARE_PATH} && find -H ${(qq)GBARE_PATH} -mindepth 1 -maxdepth 1 -type d -name '*.git'"); then
    return 1
  fi
  listing=$(print -r -- "$listing" | LC_ALL=C sort)

  # Publish only if no mutation invalidated this key while the fetch ran.
  if [[ $use_cache == true ]] &&
     [[ "$(cat -- "${file}.gen" 2>/dev/null)" == "$generation" ]]; then
    _gbare_cache_store "$listing"
  fi

  [[ -z "$listing" ]] || print -r -- "$listing"
  return 0
}

# ========================================
# Bounded parallel execution
# ========================================

# Run one command per item, at most GBARE_JOBS at a time.
# Usage: _gbare_parallel <runner> <item>...
# Args:
#   runner - Function called as "<runner> <item>"; it prints its own report
#   item   - One positional argument per invocation
# Returns:
#   0 when every invocation succeeded, 1 otherwise
# Note:
#   Concurrent runs buffer their output and replay it in item order, so reports
#   stay readable while the work itself overlaps.
_gbare_parallel() {
  local runner=$1
  shift
  local -a items=("$@")
  (( ${#items[@]} )) || return 0

  local jobs=${GBARE_JOBS:-1}
  [[ $jobs == <-> ]] || jobs=1
  (( jobs >= 1 )) || jobs=1

  local rc=0 item
  if (( jobs == 1 || ${#items[@]} == 1 )); then
    for item in "${items[@]}"; do
      "$runner" "$item" || rc=1
    done
    return $rc
  fi

  local work_dir
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gbare-parallel.XXXXXX") || return 1

  local -a pids=()
  local index=0 code
  for item in "${items[@]}"; do
    index=$((index + 1))
    if (( ${#pids[@]} >= jobs )); then
      wait "${pids[1]}" 2>/dev/null
      pids=("${pids[@]:1}")
    fi
    (
      "$runner" "$item" >| "${work_dir}/${index}.out" 2>&1
      print -r -- $? >| "${work_dir}/${index}.status"
    ) &
    pids+=($!)
  done

  local pid
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null
  done

  index=0
  for item in "${items[@]}"; do
    index=$((index + 1))
    [[ -f "${work_dir}/${index}.out" ]] && cat -- "${work_dir}/${index}.out"
    code=''
    [[ -f "${work_dir}/${index}.status" ]] && code=$(<"${work_dir}/${index}.status")
    [[ "$code" == 0 ]] || rc=1
  done

  rm -rf -- "$work_dir"
  return $rc
}
