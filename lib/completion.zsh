# ========================================
# Zsh Completion
# ========================================

# Fetch repository list from remote server for use in tab completion
# Usage: _gbare_repos
# Returns:
#   Populates completion candidates with repository names
# Note:
#   This function is called internally by zsh completion system
_gbare_repos() {
  _gbare_ensure_config

  local repos
  repos=(${(f)"$(_gbare_ssh "ls -1d $(_gbare_quote "$GBARE_PATH")/*.git 2>/dev/null" 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')"})
  _describe 'repository' repos
}

# Main zsh completion function for gbare command
# Provides tab completion for gbare subcommands and arguments
# Usage: (called by zsh completion system)
# Completion behavior:
#   - First tab: shows available subcommands
#   - Second tab (for clone/delete/info/url/search): shows repository names from server
#   - Second tab (for create/remote/sync): no completion (uses current directory name)
# Registers with:
#   compdef _gbare gbare
_gbare() {
  local line state

  _arguments -C \
    "1: :->cmds" \
    "*::arg:->args"

  case "$state" in
    cmds)
      _values "gbare command" \
        "create[Create a new bare repository]" \
        "list[List all repositories]" \
        "clone[Clone a repository]" \
        "delete[Delete a repository]" \
        "info[Show repository information]" \
        "url[Get repository SSH URL]" \
        "remote[Add remote to existing local repo]" \
        "sync[Sync local repo with remote]" \
        "backup[Backup all repositories]" \
        "search[Search repositories by name]" \
        "config[Show current configuration]" \
        "profiles[List available profiles]" \
        "profile[Show profile settings]" \
        "validate[Validate configuration]" \
        "help[Show help]"
      ;;
    args)
      case $line[1] in
        clone|cl|delete|rm|d|info|i|url|u|search|se)
          _gbare_repos
          ;;
        create|c|remote|r|sync|s)
          # create, remote, sync use current directory name by default
          ;;
      esac
      ;;
  esac
}

compdef _gbare gbare


# ========================================
# Initialization
# ========================================

# Plugin loading is silent by default.
# To enable a startup message, uncomment the following line:
# echo "gbare loaded (server: ${GBARE_HOST})"
