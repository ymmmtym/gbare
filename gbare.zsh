#!/usr/bin/env zsh

# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# 設定（環境変数で上書き可能）
: ${GBARE_USER:="yumenomatayume"}
: ${GBARE_HOST:="nas"}
: ${GBARE_PORT:=""}  # 空文字列がデフォルト（22を指定しない）
: ${GBARE_PATH:="/volume1/homes/${GBARE_USER}/git"}

# ========================================
# Error Handling Configuration
# ========================================

# SSH接続タイムアウト（秒）
: ${GBARE_SSH_TIMEOUT:="10"}

# エラーメッセージ用カラー（ターミナルが対応している場合）
if [[ -t 1 ]]; then
  _GBARE_RED=$'\033[0;31m'
  _GBARE_YELLOW=$'\033[0;33m'
  _GBARE_GREEN=$'\033[0;32m'
  _GBARE_RESET=$'\033[0m'
else
  _GBARE_RED=""
  _GBARE_YELLOW=""
  _GBARE_GREEN=""
  _GBARE_RESET=""
fi

# ========================================
# Helper Functions
# ========================================

# SSH コマンドを構築（ポート指定を適切に処理）
_gbare_ssh() {
  local ssh_opts="-o LogLevel=ERROR -o ConnectTimeout=${GBARE_SSH_TIMEOUT} -o ServerAliveInterval=5 -o ServerAliveCountMax=2"

  if [[ -n "$GBARE_PORT" ]]; then
    ssh ${ssh_opts} -p ${GBARE_PORT} ${GBARE_USER}@${GBARE_HOST} "$@"
  else
    ssh ${ssh_opts} ${GBARE_USER}@${GBARE_HOST} "$@"
  fi
}

# SSH接続チェック
_gbare_check_ssh() {
  local output
  output=$(_gbare_ssh "echo OK" 2>&1)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "${_GBARE_RED}Error: SSH connection failed${_GBARE_RESET}"
    echo "  Host: ${GBARE_HOST}"
    if [[ -n "$GBARE_PORT" ]]; then
      echo "  Port: ${GBARE_PORT}"
    fi
    echo "  User: ${GBARE_USER}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check your network connection"
    echo "  2. Verify SSH key is configured: ssh-add -l"
    echo "  3. Test connection: ssh ${GBARE_USER}@${GBARE_HOST} 'echo test'"
    if [[ $exit_code -eq 255 ]]; then
      echo "  4. Connection was refused or timed out"
    fi
    return 1
  fi

  return 0
}

# リポジトリ存在チェック
_gbare_check_repo_exists() {
  local repo_name=$1

  _gbare_ssh "test -d ${GBARE_PATH}/${repo_name}.git" 2>/dev/null
  return $?
}

# エラーメッセージ表示
_gbare_error() {
  echo "${_GBARE_RED}Error: $1${_GBARE_RESET}" >&2
}

# 警告メッセージ表示
_gbare_warn() {
  echo "${_GBARE_YELLOW}Warning: $1${_GBARE_RESET}"
}

# 成功メッセージ表示
_gbare_ok() {
  echo "${_GBARE_GREEN}$1${_GBARE_RESET}"
}

# リモート URL を構築（ポート指定を適切に処理）
_gbare_remote_url() {
  local repo_name=$1
  if [[ -n "$GBARE_PORT" ]]; then
    echo "ssh://${GBARE_USER}@${GBARE_HOST}:${GBARE_PORT}${GBARE_PATH}/${repo_name}.git"
  else
    echo "ssh://${GBARE_USER}@${GBARE_HOST}${GBARE_PATH}/${repo_name}.git"
  fi
}

# ========================================
# Core Functions
# ========================================

# リポジトリ作成
_gbare_create() {
  local repo_name=""
  local auto_yes=false
  
  # 引数をパース
  while [[ $# -gt 0 ]]; do
    case $1 in
      -y|--yes)
        auto_yes=true
        shift
        ;;
      *)
        repo_name=$1
        shift
        ;;
    esac
  done
  
  # 引数がなければカレントディレクトリ名を使用
  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$PWD")
    echo "No repository name provided, using current directory name: ${repo_name}"
  fi
  
  # 確認
  if [[ "$auto_yes" == false ]]; then
    echo ""
    echo "Creating bare repository:"
    echo "  Name: ${repo_name}.git"
    echo "  Server: ${GBARE_HOST}"
    if [[ -n "$GBARE_PORT" ]]; then
      echo "  Port: ${GBARE_PORT}"
    fi
    echo "  Path: ${GBARE_PATH}/${repo_name}.git"
    echo ""
    echo -n "Continue? (y/N): "
    read confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
      echo "Cancelled"
      return 0
    fi
  fi
  
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi
  
  echo ""
  echo "Creating bare repository: ${repo_name}.git"
  
  # 既存リポジトリのチェック
  if _gbare_check_repo_exists "${repo_name}"; then
    _gbare_warn "Repository '${repo_name}.git' already exists on ${GBARE_HOST}"
    return 1
  fi
  
  # NAS/サーバー上にベアリポジトリを作成
  local output
  output=$(_gbare_ssh "git init --bare ${GBARE_PATH}/${repo_name}.git" 2>&1)
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    _gbare_ok "Bare repository created on ${GBARE_HOST}"
    
    # ローカルをgit init（既存のリポジトリでなければ）
    if [[ ! -d .git ]]; then
      git init
      _gbare_ok "Local repository initialized"
    fi
    
    # リモートを追加
    local remote_url=$(_gbare_remote_url "${repo_name}")
    git remote add origin ${remote_url} 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
      _gbare_ok "Remote 'origin' added"
    else
      _gbare_warn "Remote 'origin' already exists"
    fi
    
    echo ""
    echo "Repository URL: ${remote_url}"
    echo ""
    echo "Next steps:"
    echo "  git add ."
    echo "  git commit -m 'first commit'"
    echo "  git push -u origin main"
  else
    _gbare_error "Failed to create repository on ${GBARE_HOST}"
    if [[ -n "$output" ]]; then
      echo "  Details: ${output}"
    fi
    return 1
  fi
}

# リポジトリ一覧
_gbare_list() {
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi

  echo "Bare repositories on ${GBARE_HOST}:"
  echo ""
  
  local output
  output=$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>&1)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    _gbare_error "Failed to list repositories"
    echo "  Details: ${output}"
    return 1
  fi
  
  if [[ -z "$output" ]]; then
    echo "No repositories found"
    return 0
  fi
  
  echo "$output" | sed 's/.*\///' | sed 's/\.git$//' | while read repo; do
    echo "  • $repo"
  done
}

# リポジトリクローン
_gbare_clone() {
  local repo_name=$1
  local target_dir=$2
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare clone <repository-name> [directory]"
    return 1
  fi
  
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi
  
  # リポジトリ存在チェック
  if ! _gbare_check_repo_exists "${repo_name}"; then
    _gbare_error "Repository '${repo_name}.git' does not exist on ${GBARE_HOST}"
    echo ""
    echo "Available repositories:"
    _gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//' | while read repo; do
      echo "  • $repo"
    done
    return 1
  fi
  
  local remote_url=$(_gbare_remote_url "${repo_name}")
  
  echo "Cloning from: ${remote_url}"
  
  local output
  if [[ -n "$target_dir" ]]; then
    output=$(git clone ${remote_url} ${target_dir} 2>&1)
  else
    output=$(git clone ${remote_url} 2>&1)
  fi
  local exit_code=$?
  
  if [[ $exit_code -ne 0 ]]; then
    _gbare_error "Failed to clone repository"
    echo "  Details: ${output}"
    return 1
  fi
  
  _gbare_ok "Repository cloned successfully"
}

# リポジトリ削除
_gbare_delete() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare delete <repository-name>"
    return 1
  fi
  
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi
  
  # リポジトリ存在チェック
  if ! _gbare_check_repo_exists "${repo_name}"; then
    _gbare_error "Repository '${repo_name}.git' does not exist on ${GBARE_HOST}"
    return 1
  fi
  
  echo "⚠️  WARNING: This will permanently delete ${repo_name}.git from ${GBARE_HOST}"
  echo "  Path: ${GBARE_PATH}/${repo_name}.git"
  echo ""
  echo -n "Type repository name to confirm: "
  read confirmation
  
  if [[ "$confirmation" == "$repo_name" ]]; then
    local output
    output=$(_gbare_ssh "rm -rf ${GBARE_PATH}/${repo_name}.git" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
      _gbare_ok "Repository deleted: ${repo_name}.git"
    else
      _gbare_error "Failed to delete repository"
      echo "  Details: ${output}"
      return 1
    fi
  else
    echo "Cancelled (input did not match)"
  fi
}

# リポジトリ情報
_gbare_info() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare info <repository-name>"
    return 1
  fi
  
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi
  
  # リポジトリ存在チェック
  if ! _gbare_check_repo_exists "${repo_name}"; then
    _gbare_error "Repository '${repo_name}.git' does not exist on ${GBARE_HOST}"
    return 1
  fi
  
  local remote_url=$(_gbare_remote_url "${repo_name}")
  
  echo "Repository: ${repo_name}.git"
  echo "Server: ${GBARE_HOST}"
  if [[ -n "$GBARE_PORT" ]]; then
    echo "Port: ${GBARE_PORT}"
  fi
  echo "SSH URL: ${remote_url}"
  
  if command -v git >/dev/null 2>&1; then
    echo ""
    echo "Branches and tags:"
    local output
    output=$(_gbare_ssh "cd ${GBARE_PATH}/${repo_name}.git && git show-ref 2>/dev/null" 2>&1)
    
    if [[ -z "$output" ]]; then
      echo "  (empty repository)"
    else
      echo "$output" | while read line; do
        echo "  $line"
      done
    fi
  fi
}

# リモートURL取得（既存リポジトリ用）
_gbare_url() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare url <repository-name>"
    return 1
  fi
  
  _gbare_remote_url "${repo_name}"
}

# 既存ローカルリポジトリにリモート追加
_gbare_remote() {
  local repo_name=""
  local remote_name="origin"
  local auto_yes=false
  
  # 引数をパース
  while [[ $# -gt 0 ]]; do
    case $1 in
      -y|--yes)
        auto_yes=true
        shift
        ;;
      *)
        if [[ -z "$repo_name" ]]; then
          repo_name=$1
        else
          remote_name=$1
        fi
        shift
        ;;
    esac
  done
  
  # 引数がなければカレントディレクトリ名を使用
  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$PWD")
    echo "No repository name provided, using current directory name: ${repo_name}"
  fi
  
  if [[ ! -d .git ]]; then
    _gbare_error "Not a git repository (no .git directory found)"
    return 1
  fi
  
  # SSH接続チェック
  if ! _gbare_check_ssh; then
    return 1
  fi
  
  # リポジトリ存在チェック
  if ! _gbare_check_repo_exists "${repo_name}"; then
    _gbare_error "Repository '${repo_name}.git' does not exist on ${GBARE_HOST}"
    return 1
  fi
  
  local remote_url=$(_gbare_remote_url "${repo_name}")
  
  # 確認
  if [[ "$auto_yes" == false ]]; then
    echo ""
    echo "Adding remote:"
    echo "  Name: ${remote_name}"
    echo "  Repository: ${repo_name}.git"
    echo "  URL: ${remote_url}"
    echo ""
    echo -n "Continue? (y/N): "
    read confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
      echo "Cancelled"
      return 0
    fi
  fi
  
  local output
  output=$(git remote add ${remote_name} ${remote_url} 2>&1)
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    _gbare_ok "Remote '${remote_name}' added: ${remote_url}"
  else
    _gbare_error "Failed to add remote (may already exist)"
    echo "  Details: ${output}"
    return 1
  fi
}

# 設定表示
_gbare_config() {
  echo "gbare configuration:"
  echo ""
  echo "  GBARE_USER: ${GBARE_USER}"
  echo "  GBARE_HOST: ${GBARE_HOST}"
  echo "  GBARE_PORT: ${GBARE_PORT:-"(default)"}"
  echo "  GBARE_PATH: ${GBARE_PATH}"
  echo "  GBARE_SSH_TIMEOUT: ${GBARE_SSH_TIMEOUT}s"
  echo ""
  echo "Set these in your ~/.zshrc or Sheldon plugins.toml"
}

# ========================================
# Main Command (subcommand style)
# ========================================

gbare() {
  local cmd=$1
  shift
  
  case "$cmd" in
    create|c)
      _gbare_create "$@"
      ;;
    list|ls|l)
      _gbare_list "$@"
      ;;
    clone|cl)
      _gbare_clone "$@"
      ;;
    delete|rm|d)
      _gbare_delete "$@"
      ;;
    info|i)
      _gbare_info "$@"
      ;;
    url|u)
      _gbare_url "$@"
      ;;
    remote|r)
      _gbare_remote "$@"
      ;;
    config|cfg)
      _gbare_config "$@"
      ;;
    help|h|--help|-h|"")
      echo "gbare - Bare Repository Manager"
      echo ""
      echo "Manage bare Git repositories on remote servers (Linux/NAS)"
      echo ""
      echo "Usage: gbare <command> [options]"
      echo ""
      echo "Commands:"
      echo "  create, c     [name] [-y|--yes]  Create a new bare repository"
      echo "                                   (uses current directory name if not specified)"
      echo "                                   -y, --yes: Skip confirmation prompt"
      echo "  list, ls, l                      List all repositories"
      echo "  clone, cl     <name> [dir]       Clone a repository"
      echo "  delete, rm, d <name>             Delete a repository"
      echo "  info, i       <name>             Show repository information"
      echo "  url, u        <name>             Get repository SSH URL"
      echo "  remote, r     [name] [remote] [-y|--yes]"
      echo "                                   Add remote to existing local repo"
      echo "                                   (uses current directory name if not specified)"
      echo "                                   -y, --yes: Skip confirmation prompt"
      echo "  config, cfg                      Show current configuration"
      echo "  help, h                          Show this help"
      echo ""
      echo "Configuration (set in ~/.zshrc or Sheldon):"
      echo "  GBARE_USER  - SSH username (default: yumenomatayume)"
      echo "  GBARE_HOST  - Server hostname or IP (default: nas)"
      echo "  GBARE_PORT  - SSH port (optional, defaults to 22)"
      echo "  GBARE_PATH  - Path to git repositories (default: /volume1/homes/\${GBARE_USER}/git)"
      echo ""
      echo "Examples:"
      echo "  gbare create                     # Create repo with current dir name"
      echo "  gbare create -y                  # Create without confirmation"
      echo "  gbare create myproject           # Create new repo and init local"
      echo "  gbare create myproject -y        # Create without confirmation"
      echo "  gbare list                       # List all repos on server"
      echo "  gbare clone myproject            # Clone existing repo"
      echo "  gbare remote                     # Add remote with current dir name"
      echo "  gbare remote -y                  # Add remote without confirmation"
      echo "  gbare remote myproject           # Add remote to current repo"
      echo "  gbare remote myproject origin -y # Add remote without confirmation"
      echo "  gbare url myproject              # Get SSH URL"
      ;;
    *)
      echo "Unknown command: $cmd"
      echo "Run 'gbare help' for usage information"
      return 1
      ;;
  esac
}

# ========================================
# Completion
# ========================================

# リポジトリリスト取得（補完用）
_gbare_repos() {
  local repos
  local output
  output=$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')
  repos=(${(f)"$output"})
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
        "config[Show current configuration]" \
        "help[Show help]"
      ;;
    args)
      case $line[1] in
        clone|cl|delete|rm|d|info|i|url|u)
          _gbare_repos
          ;;
        create|c|remote|r)
          # create と remote はオプショナルなので補完しない（カレントディレクトリ名を使う）
          ;;
      esac
      ;;
  esac
}

compdef _gbare gbare

# ========================================
# Initialization
# ========================================

# プラグイン読み込み時のメッセージ（オプション）
# echo "gbare loaded (server: ${GBARE_HOST})"
