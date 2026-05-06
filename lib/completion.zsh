# ========================================
# gbare - Completion Functions
# ========================================

# リポジトリリスト取得（補完用）
_gbare_repos() {
  local repos
  repos=(${(f)"$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')"})
  _describe 'repository' repos
}

# メイン補完関数
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
