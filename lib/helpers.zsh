# ========================================
# Helper Functions
# ========================================

# Execute command on remote server via SSH
# Usage: _gbare_ssh <command>
# Args:
#   command - Shell command to execute on remote server
# Returns:
#   Exit status of remote command
# Example:
#   _gbare_ssh "git init --bare /path/to/repo.git"
_gbare_ssh() {
  if [[ -n "$GBARE_PORT" ]]; then
    ssh -o LogLevel=ERROR -p ${GBARE_PORT} ${GBARE_USER}@${GBARE_HOST} "$@"
  else
    ssh -o LogLevel=ERROR ${GBARE_USER}@${GBARE_HOST} "$@"
  fi
}

# Build SSH URL for a remote repository
# Usage: _gbare_remote_url <repo_name>
# Args:
#   repo_name - Name of the repository (without .git suffix)
# Returns:
#   Echoes the full SSH URL to the repository
# Example:
#   url=$(_gbare_remote_url "myproject")
#   # => ssh://user@host/path/to/myproject.git
_gbare_remote_url() {
  local repo_name=$1
  if [[ -n "$GBARE_PORT" ]]; then
    echo "ssh://${GBARE_USER}@${GBARE_HOST}:${GBARE_PORT}${GBARE_PATH}/${repo_name}.git"
  else
    echo "ssh://${GBARE_USER}@${GBARE_HOST}${GBARE_PATH}/${repo_name}.git"
  fi
}

