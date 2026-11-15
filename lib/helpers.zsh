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


# Emit repository paths, succeeding with no output for an empty directory.
_gbare_repository_paths() {
  _gbare_ssh "test -d ${(qq)GBARE_PATH} && for repo in ${(qq)GBARE_PATH}/*.git; do [ -d \"\$repo\" ] || continue; printf '%s\\n' \"\$repo\"; done"
}
