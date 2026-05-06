#!/usr/bin/env zsh

# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# ========================================
# Configuration
# ========================================

# GBARE_USER - SSH username for remote server
# Default: "yumenomatayume"
: ${GBARE_USER:="yumenomatayume"}

# GBARE_HOST - Remote server hostname or IP address
# Default: "nas"
: ${GBARE_HOST:="nas"}

# GBARE_PORT - SSH port number (empty string means default port 22)
# Default: "" (uses SSH default port 22)
: ${GBARE_PORT:=""}

# GBARE_PATH - Base path for bare repositories on remote server
# Default: "/volume1/homes/${GBARE_USER}/git"
: ${GBARE_PATH:="/volume1/homes/${GBARE_USER}/git"}

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

# ========================================
# Core Functions
# ========================================

# Create a new bare repository on the remote server and optionally initialize local repo
# Usage: _gbare_create [repo_name] [-y|--yes]
# Args:
#   repo_name       - Name for the repository (defaults to current directory name)
#   -y, --yes       - Skip confirmation prompt
# Returns:
#   0 on success, 1 on failure
# Side effects:
#   - Creates bare repository on remote server
#   - Initializes local git repo if not already initialized
#   - Adds 'origin' remote pointing to the new repository
# Example:
#   _gbare_create                    # Uses current directory name with confirmation
#   _gbare_create myproject -y       # Creates "myproject" without confirmation
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
  
  echo ""
  echo "Creating bare repository: ${repo_name}.git"
  
  # NAS/サーバー上にベアリポジトリを作成
  _gbare_ssh "git init --bare ${GBARE_PATH}/${repo_name}.git"
  
  if [[ $? -eq 0 ]]; then
    echo "✓ Bare repository created on ${GBARE_HOST}"
    
    # ローカルをgit init（既存のリポジトリでなければ）
    if [[ ! -d .git ]]; then
      git init
      echo "✓ Local repository initialized"
    fi
    
    # リモートを追加
    local remote_url=$(_gbare_remote_url "${repo_name}")
    git remote add origin ${remote_url} 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
      echo "✓ Remote 'origin' added"
    else
      echo "⚠ Remote 'origin' already exists"
    fi
    
    echo ""
    echo "Repository URL: ${remote_url}"
    echo ""
    echo "Next steps:"
    echo "  git add ."
    echo "  git commit -m 'first commit'"
    echo "  git push -u origin main"
  else
    echo "✗ Failed to create repository"
    return 1
  fi
}

# List all bare repositories on the remote server
# Usage: _gbare_list
# Returns:
#   0 on success, 1 on failure
# Output:
#   Prints list of repository names (without .git suffix)
# Example:
#   _gbare_list
#   # => Bare repositories on nas:
#   # =>   • project1
#   # =>   • project2
_gbare_list() {
  echo "Bare repositories on ${GBARE_HOST}:"
  echo ""
  
  local repos=$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null)
  
  if [[ -z "$repos" ]]; then
    echo "No repositories found"
    return 0
  fi
  
  echo "$repos" | sed 's/.*\///' | sed 's/\.git$//' | while read repo; do
    echo "  • $repo"
  done
}

# Clone a repository from the remote server
# Usage: _gbare_clone <repo_name> [target_dir]
# Args:
#   repo_name  - Name of the repository to clone (required)
#   target_dir - Directory to clone into (optional, defaults to repo name)
# Returns:
#   0 on success, 1 if repo_name is not provided
# Example:
#   _gbare_clone myproject                  # Clones to ./myproject/
#   _gbare_clone myproject ~/work/project   # Clones to specified directory
_gbare_clone() {
  local repo_name=$1
  local target_dir=$2
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare clone <repository-name> [directory]"
    return 1
  fi
  
  local remote_url=$(_gbare_remote_url "${repo_name}")
  
  echo "Cloning from: ${remote_url}"
  
  if [[ -n "$target_dir" ]]; then
    git clone ${remote_url} ${target_dir}
  else
    git clone ${remote_url}
  fi
}

# Delete a repository from the remote server
# Usage: _gbare_delete <repo_name>
# Args:
#   repo_name - Name of the repository to delete (required)
# Returns:
#   0 on success, 1 if repo_name is not provided or deletion fails
# Note:
#   Requires typing the repository name for confirmation to prevent accidental deletion
# Example:
#   _gbare_delete myproject
#   # => WARNING: This will permanently delete myproject.git from nas
#   # => Type repository name to confirm: myproject
#   # => Repository deleted: myproject.git
_gbare_delete() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare delete <repository-name>"
    return 1
  fi
  
  echo "⚠️  WARNING: This will permanently delete ${repo_name}.git from ${GBARE_HOST}"
  echo "  Path: ${GBARE_PATH}/${repo_name}.git"
  echo ""
  echo -n "Type repository name to confirm: "
  read confirmation
  
  if [[ "$confirmation" == "$repo_name" ]]; then
    _gbare_ssh "rm -rf ${GBARE_PATH}/${repo_name}.git"
    
    if [[ $? -eq 0 ]]; then
      echo "✓ Repository deleted: ${repo_name}.git"
    else
      echo "✗ Failed to delete repository"
      return 1
    fi
  else
    echo "Cancelled (input did not match)"
  fi
}

# Show information about a repository on the remote server
# Usage: _gbare_info <repo_name>
# Args:
#   repo_name - Name of the repository (required)
# Returns:
#   0 on success, 1 if repo_name is not provided
# Output:
#   Prints repository name, server, port (if configured), SSH URL, and branches/tags
# Example:
#   _gbare_info myproject
#   # => Repository: myproject.git
#   # => Server: nas
#   # => SSH URL: ssh://user@nas/path/myproject.git
#   # => Branches and tags:
_gbare_info() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare info <repository-name>"
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
    _gbare_ssh "cd ${GBARE_PATH}/${repo_name}.git && git show-ref 2>/dev/null" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
      echo "  (empty repository or connection failed)"
    fi
  fi
}

# Get the SSH URL for a repository
# Usage: _gbare_url <repo_name>
# Args:
#   repo_name - Name of the repository (required)
# Returns:
#   0 on success, 1 if repo_name is not provided
# Output:
#   Echoes the SSH URL for the repository
# Example:
#   _gbare_url myproject
#   # => ssh://user@nas/path/myproject.git
_gbare_url() {
  local repo_name=$1
  
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gbare url <repository-name>"
    return 1
  fi
  
  _gbare_remote_url "${repo_name}"
}

# Add a remote to an existing local git repository
# Usage: _gbare_remote [repo_name] [remote_name] [-y|--yes]
# Args:
#   repo_name    - Name of the remote repository (defaults to current directory name)
#   remote_name  - Name for the remote (defaults to "origin")
#   -y, --yes    - Skip confirmation prompt
# Returns:
#   0 on success, 1 if not in a git repository or remote already exists
# Prerequisites:
#   Current directory must be a git repository (have .git directory)
# Example:
#   _gbare_remote                    # Uses current dir name, adds as "origin"
#   _gbare_remote myproject upstream # Adds as "upstream" remote
#   _gbare_remote -y                 # Skips confirmation
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
    echo "✗ Not a git repository (no .git directory found)"
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
  
  git remote add ${remote_name} ${remote_url}
  
  if [[ $? -eq 0 ]]; then
    echo "✓ Remote '${remote_name}' added: ${remote_url}"
  else
    echo "✗ Failed to add remote (may already exist)"
    return 1
  fi
}

# Display the current gbare configuration
# Usage: _gbare_config
# Returns:
#   Always returns 0
# Output:
#   Prints current values of GBARE_USER, GBARE_HOST, GBARE_PORT, and GBARE_PATH
# Example:
#   _gbare_config
#   # => gbare configuration:
#   # =>   GBARE_USER: user
#   # =>   GBARE_HOST: nas
#   # =>   GBARE_PORT: (default)
#   # =>   GBARE_PATH: /volume1/homes/user/git
_gbare_config() {
  echo "gbare configuration:"
  echo ""
  echo "  GBARE_USER: ${GBARE_USER}"
  echo "  GBARE_HOST: ${GBARE_HOST}"
  echo "  GBARE_PORT: ${GBARE_PORT:-"(default)"}"
  echo "  GBARE_PATH: ${GBARE_PATH}"
  echo ""
  echo "Set these in your ~/.zshrc or Sheldon plugins.toml"
}

# Main entry point for gbare commands
# Dispatches subcommands to appropriate handler functions
# Usage: gbare <command> [args...]
# Commands:
#   create, c     - Create a new bare repository
#   list, ls, l   - List all repositories
#   clone, cl     - Clone a repository
#   delete, rm, d - Delete a repository
#   info, i       - Show repository information
#   url, u        - Get repository SSH URL
#   remote, r     - Add remote to existing local repo
#   config, cfg   - Show current configuration
#   help, h       - Show help message
# Returns:
#   0 on success, 1 on unknown command
# Example:
#   gbare create myproject
#   gbare list
#   gbare help
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
# Zsh Completion
# ========================================

# Fetch repository list from remote server for use in tab completion
# Usage: _gbare_repos
# Returns:
#   Populates completion candidates with repository names
# Note:
#   This function is called internally by zsh completion system
_gbare_repos() {
  local repos
  repos=(${(f)"$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')"})
  _describe 'repository' repos
}

# Main zsh completion function for gbare command
# Provides tab completion for gbare subcommands and arguments
# Usage: (called by zsh completion system)
# Completion behavior:
#   - First tab: shows available subcommands
#   - Second tab (for clone/delete/info/url): shows repository names from server
#   - Second tab (for create/remote): no completion (uses current directory name)
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

# Plugin loading is silent by default.
# To enable a startup message, uncomment the following line:
# echo "gbare loaded (server: ${GBARE_HOST})"
