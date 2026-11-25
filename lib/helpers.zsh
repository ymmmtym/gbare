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
_gbare_cache_file() {
  local key="${GBARE_USER}@${GBARE_HOST}:${GBARE_PORT:-22}:${GBARE_PATH}"
  print -r -- "${GBARE_CACHE_DIR}/${${key}//[^A-Za-z0-9._-]/_}.repos"
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

_gbare_cache_store() {
  _gbare_cache_enabled || return 0

  local file dir
  file=$(_gbare_cache_file)
  dir=${file:h}
  mkdir -p -- "$dir" 2>/dev/null || return 0

  local tmp="${file}.$$"
  if print -r -- "$1" >| "$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$file" 2>/dev/null || rm -f -- "$tmp"
  fi
  return 0
}

# Drop the cached listing; call after any change to the remote repository set.
_gbare_cache_invalidate() {
  rm -f -- "$(_gbare_cache_file)" 2>/dev/null
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

  # find keeps the result independent of the remote shell's unset-glob
  # behaviour, which differs between sh and zsh remotes. A missing base path
  # still fails, so a mistyped GBARE_PATH is reported instead of looking empty.
  if ! listing=$(_gbare_ssh "test -d ${(qq)GBARE_PATH} && find ${(qq)GBARE_PATH} -mindepth 1 -maxdepth 1 -type d -name '*.git' | LC_ALL=C sort"); then
    return 1
  fi

  [[ $use_cache == false ]] || _gbare_cache_store "$listing"

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
