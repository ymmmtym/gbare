#!/usr/bin/env zsh

# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# ========================================
# Configuration
# ========================================

# Config file path for INI-style profile definitions
GBARE_CONFIG_FILE="${GBARE_CONFIG_FILE:-${HOME}/.config/gbare/config}"

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

# GBARE_PROFILE - Active profile name for config file selection
# Default: "default"
: ${GBARE_PROFILE:="default"}

# GBARE_COLOR - Enable color output
# Default: "true"
: ${GBARE_COLOR:="true"}

# Color definitions
if [[ "$GBARE_COLOR" == "true" ]]; then
  GBARE_COLOR_RESET=$'\033[0m'
  GBARE_COLOR_RED=$'\033[0;31m'
  GBARE_COLOR_GREEN=$'\033[0;32m'
  GBARE_COLOR_YELLOW=$'\033[0;33m'
  GBARE_COLOR_BLUE=$'\033[0;34m'
  GBARE_COLOR_CYAN=$'\033[0;36m'
  GBARE_COLOR_BOLD=$'\033[1m'
else
  GBARE_COLOR_RESET=""
  GBARE_COLOR_RED=""
  GBARE_COLOR_GREEN=""
  GBARE_COLOR_YELLOW=""
  GBARE_COLOR_BLUE=""
  GBARE_COLOR_CYAN=""
  GBARE_COLOR_BOLD=""
fi

# ========================================
# Config File Loading
# ========================================

# Load settings from INI-style config file
# Supports [profile] sections and key=value pairs
_gbare_load_config() {
  local config_file="${GBARE_CONFIG_FILE}"
  local current_profile="default"
  local target_profile="${GBARE_PROFILE}"
  local has_profiles=false

  if [[ ! -f "$config_file" ]]; then
    return 0
  fi

  # First check if the file has any profile sections
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line## }"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      has_profiles=true
      break
    fi
  done < "$config_file"

  # No profile sections: treat entire file as default profile
  if [[ "$has_profiles" == false ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line## }"
      line="${line%% }"
      [[ -z "$line" ]] && continue

      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        local key="${match[1]}"
        local value="${match[2]}"
        value="${value%% }"

        case "$key" in
          GBARE_USER)  export GBARE_USER="$value" ;;
          GBARE_HOST)  export GBARE_HOST="$value" ;;
          GBARE_PORT)  export GBARE_PORT="$value" ;;
          GBARE_PATH)  export GBARE_PATH="$value" ;;
          GBARE_COLOR) export GBARE_COLOR="$value" ;;
        esac
      fi
    done < "$config_file"
    return 0
  fi

  # Profile sections exist: only load the target profile
  local in_target_profile=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line## }"
    line="${line%% }"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      current_profile="${match[1]}"
      if [[ "$current_profile" == "$target_profile" ]]; then
        in_target_profile=true
      else
        in_target_profile=false
      fi
      continue
    fi

    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${match[1]}"
      local value="${match[2]}"
      value="${value%% }"

      if [[ "$in_target_profile" == true ]]; then
        case "$key" in
          GBARE_USER)  export GBARE_USER="$value" ;;
          GBARE_HOST)  export GBARE_HOST="$value" ;;
          GBARE_PORT)  export GBARE_PORT="$value" ;;
          GBARE_PATH)  export GBARE_PATH="$value" ;;
          GBARE_COLOR) export GBARE_COLOR="$value" ;;
        esac
      fi
    fi
  done < "$config_file"

  return 0
}

# Validate current configuration settings
# Checks that required values are set and GBARE_PORT is valid
_gbare_validate_settings() {
  local errors=()

  if [[ -z "$GBARE_USER" ]]; then
    errors+=("GBARE_USER is required")
  fi

  if [[ -z "$GBARE_HOST" ]]; then
    errors+=("GBARE_HOST is required")
  fi

  if [[ -z "$GBARE_PATH" ]]; then
    errors+=("GBARE_PATH is required")
  fi

  if [[ -n "$GBARE_PORT" ]]; then
    if ! [[ "$GBARE_PORT" =~ ^[0-9]+$ ]]; then
      errors+=("GBARE_PORT must be a number")
    elif [[ "$GBARE_PORT" -lt 1 || "$GBARE_PORT" -gt 65535 ]]; then
      errors+=("GBARE_PORT must be between 1 and 65535")
    fi
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "Configuration errors:"
    for error in "${errors[@]}"; do
      echo "  - $error"
    done
    return 1
  fi

  return 0
}

# List all available profiles from the config file
_gbare_list_profiles() {
  local config_file="${GBARE_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "No config file found at: ${config_file}"
    return 1
  fi

  echo "Available profiles:"
  echo ""

  local profiles=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      profiles+=("${match[1]}")
    fi
  done < "$config_file"

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "  (no profiles defined)"
  else
    for profile in "${profiles[@]}"; do
      if [[ "$profile" == "$GBARE_PROFILE" ]]; then
        echo "  * $profile (active)"
      else
        echo "  - $profile"
      fi
    done
  fi
}

# Show settings for a specific profile
# Usage: _gbare_show_profile [profile_name]
_gbare_show_profile() {
  local profile_name="${1:-$GBARE_PROFILE}"
  local config_file="${GBARE_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "No config file found at: ${config_file}"
    return 1
  fi

  local in_profile=false
  local found=false
  local settings=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      if [[ "${match[1]}" == "$profile_name" ]]; then
        in_profile=true
        found=true
        continue
      else
        if [[ "$in_profile" == true ]]; then
          break
        fi
      fi
    fi

    if [[ "$in_profile" == true ]]; then
      line="${line%%#*}"
      line="${line## }"
      [[ -z "$line" ]] && continue
      if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        settings+=("$line")
      fi
    fi
  done < "$config_file"

  if [[ "$found" == false ]]; then
    echo "Profile not found: ${profile_name}"
    return 1
  fi

  echo "Profile: ${profile_name}"
  echo ""
  if [[ ${#settings[@]} -eq 0 ]]; then
    echo "  (no settings)"
  else
    for setting in "${settings[@]}"; do
      echo "  $setting"
    done
  fi
}

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

  # Parse arguments
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

  # Use current directory name if no argument provided
  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$PWD")
    echo "No repository name provided, using current directory name: ${repo_name}"
  fi

  # Confirmation
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

  # Create bare repository on server
  _gbare_ssh "git init --bare ${GBARE_PATH}/${repo_name}.git"

  if [[ $? -eq 0 ]]; then
    echo "✓ Bare repository created on ${GBARE_HOST}"

    # Initialize local repo if not already a git repo
    if [[ ! -d .git ]]; then
      git init
      echo "✓ Local repository initialized"
    fi

    # Add remote
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

  # Parse arguments
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

  # Use current directory name if no argument provided
  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$PWD")
    echo "No repository name provided, using current directory name: ${repo_name}"
  fi

  if [[ ! -d .git ]]; then
    echo "✗ Not a git repository (no .git directory found)"
    return 1
  fi

  local remote_url=$(_gbare_remote_url "${repo_name}")

  # Confirmation
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
#   Prints current values of all GBARE_* configuration variables
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
  echo "  Config file: ${GBARE_CONFIG_FILE}"
  if [[ -f "$GBARE_CONFIG_FILE" ]]; then
    echo "  Config file status: found"
  else
    echo "  Config file status: not found"
  fi
  echo "  Active profile: ${GBARE_PROFILE}"
  echo ""
  echo "  GBARE_USER: ${GBARE_USER}"
  echo "  GBARE_HOST: ${GBARE_HOST}"
  echo "  GBARE_PORT: ${GBARE_PORT:-"(default)"}"
  echo "  GBARE_PATH: ${GBARE_PATH}"
  echo "  GBARE_COLOR: ${GBARE_COLOR}"
  echo ""
  echo "Set these in your ~/.zshrc, Sheldon plugins.toml, or config file"
  echo ""
  echo "Use 'gbare profiles' to list available profiles"
}

# ========================================
# Extended Features
# ========================================

# Sync local repository with remote (local → remote)
# Usage: _gbare_sync [repo_name] [remote_name]
# Args:
#   repo_name   - Name of the repository (defaults to current directory name)
#   remote_name - Name of the remote (defaults to "origin")
# Returns:
#   0 on success, 1 on failure
# Prerequisites:
#   Current directory must be a git repository
# Example:
#   _gbare_sync                    # Sync current repo with origin
#   _gbare_sync myproject upstream # Sync with upstream remote
_gbare_sync() {
  local repo_name=$1
  local remote_name=${2:-origin}

  if [[ -z "$repo_name" ]]; then
    repo_name=$(basename "$PWD")
    echo "${GBARE_COLOR_CYAN}No repository name provided, using current directory name: ${repo_name}${GBARE_COLOR_RESET}"
  fi

  if [[ ! -d .git ]]; then
    echo "${GBARE_COLOR_RED}✗ Not a git repository (no .git directory found)${GBARE_COLOR_RESET}"
    return 1
  fi

  echo "${GBARE_COLOR_BLUE}Syncing repository: ${repo_name}${GBARE_COLOR_RESET}"
  echo ""

  local remote_url=$(_gbare_remote_url "${repo_name}")

  if ! git remote | grep -q "^${remote_name}$"; then
    echo "${GBARE_COLOR_YELLOW}Remote '${remote_name}' not found, adding...${GBARE_COLOR_RESET}"
    git remote add ${remote_name} ${remote_url}
  fi

  echo "${GBARE_COLOR_GREEN}Pulling latest changes...${GBARE_COLOR_RESET}"
  git pull ${remote_name} main 2>/dev/null || git pull ${remote_name} master 2>/dev/null

  echo "${GBARE_COLOR_GREEN}Pushing local changes...${GBARE_COLOR_RESET}"
  git push ${remote_name} HEAD:main 2>/dev/null || git push ${remote_name} HEAD:master 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo ""
    echo "${GBARE_COLOR_GREEN}✓ Sync completed successfully${GBARE_COLOR_RESET}"
  else
    echo ""
    echo "${GBARE_COLOR_RED}✗ Sync failed${GBARE_COLOR_RESET}"
    return 1
  fi
}

# Backup all repositories to local directory
# Usage: _gbare_backup [backup_dir]
# Args:
#   backup_dir - Directory to store backups (default: "${HOME}/gbare_backups")
# Returns:
#   0 on success
# Output:
#   Creates mirrored clones of all remote repositories in timestamped subdirectory
# Example:
#   _gbare_backup                  # Backup to ~/gbare_backups
#   _gbare_backup ~/my_backups     # Backup to specified directory
_gbare_backup() {
  local backup_dir=${1:-"${HOME}/gbare_backups"}
  local timestamp=$(date +%Y%m%d_%H%M%S)

  echo "${GBARE_COLOR_BLUE}Creating backup of all repositories...${GBARE_COLOR_RESET}"
  echo ""

  mkdir -p "${backup_dir}/${timestamp}"

  local repos=$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null)

  if [[ -z "$repos" ]]; then
    echo "${GBARE_COLOR_YELLOW}No repositories found to backup${GBARE_COLOR_RESET}"
    return 0
  fi

  echo "$repos" | while read repo_path; do
    local repo_name=$(basename "$repo_path" .git)
    echo "${GBARE_COLOR_CYAN}Backing up: ${repo_name}${GBARE_COLOR_RESET}"

    local remote_url=$(_gbare_remote_url "${repo_name}")
    local target="${backup_dir}/${timestamp}/${repo_name}"

    git clone --mirror ${remote_url} "${target}.git" 2>/dev/null

    if [[ $? -eq 0 ]]; then
      echo "${GBARE_COLOR_GREEN}  ✓ ${repo_name} backed up${GBARE_COLOR_RESET}"
    else
      echo "${GBARE_COLOR_RED}  ✗ Failed to backup ${repo_name}${GBARE_COLOR_RESET}"
    fi
  done

  echo ""
  echo "${GBARE_COLOR_GREEN}✓ Backup completed: ${backup_dir}/${timestamp}${GBARE_COLOR_RESET}"
}

# Search repositories by name
# Usage: _gbare_search <query>
# Args:
#   query - Search string (case-insensitive substring match)
# Returns:
#   0 on success, 1 if query is not provided
# Output:
#   Prints matching repository names
# Example:
#   _gbare_search myproject
#   # =>   • myproject
_gbare_search() {
  local query=$1

  if [[ -z "$query" ]]; then
    echo "Usage: gbare search <query>"
    return 1
  fi

  echo "${GBARE_COLOR_BLUE}Searching repositories for: ${query}${GBARE_COLOR_RESET}"
  echo ""

  local repos=$(_gbare_ssh "ls -1d ${GBARE_PATH}/*.git 2>/dev/null" 2>/dev/null)

  if [[ -z "$repos" ]]; then
    echo "${GBARE_COLOR_YELLOW}No repositories found${GBARE_COLOR_RESET}"
    return 0
  fi

  local found=0
  echo "$repos" | sed 's/.*\///' | sed 's/\.git$//' | while read repo; do
    if echo "$repo" | grep -i "$query" > /dev/null 2>&1; then
      echo "${GBARE_COLOR_GREEN}  • $repo${GBARE_COLOR_RESET}"
      found=1
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "${GBARE_COLOR_YELLOW}No repositories matching '${query}'${GBARE_COLOR_RESET}"
  fi
}

# ========================================
# Main Command (subcommand style)
# ========================================

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
#   sync, s       - Sync local repo with remote
#   backup, b     - Backup all repositories
#   search, se    - Search repositories by name
#   config, cfg   - Show current configuration
#   profiles, pl  - List available profiles
#   profile, p    - Show profile settings
#   validate, v   - Validate configuration
#   help, h       - Show help message
# Returns:
#   0 on success, 1 on unknown command
# Example:
#   gbare create myproject
#   gbare list
#   gbare help
gbare() {
  # Load config file on first invocation
  if [[ -z "${_GBARE_CONFIG_LOADED}" ]]; then
    _gbare_load_config
    export _GBARE_CONFIG_LOADED=true
  fi

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
    sync|s)
      _gbare_sync "$@"
      ;;
    backup|b)
      _gbare_backup "$@"
      ;;
    search|se)
      _gbare_search "$@"
      ;;
    config|cfg)
      _gbare_config "$@"
      ;;
    profiles|pl)
      _gbare_list_profiles "$@"
      ;;
    profile|p)
      _gbare_show_profile "$@"
      ;;
    validate|v)
      _gbare_validate_settings
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
      echo "  sync, s       [name] [remote]    Sync local repo with remote"
      echo "                                   (uses current directory name if not specified)"
      echo "  backup, b     [dir]              Backup all repositories to local dir"
      echo "                                   (default: ~/gbare_backups)"
      echo "  search, se    <query>            Search repositories by name"
      echo "  config, cfg                      Show current configuration"
      echo "  profiles, pl                     List available profiles"
      echo "  profile, p    [name]             Show profile settings"
      echo "  validate, v                      Validate configuration"
      echo "  help, h                          Show this help"
      echo ""
      echo "Configuration (set in ~/.zshrc, Sheldon, or config file):"
      echo "  GBARE_USER    - SSH username (default: yumenomatayume)"
      echo "  GBARE_HOST    - Server hostname or IP (default: nas)"
      echo "  GBARE_PORT    - SSH port (optional, defaults to 22)"
      echo "  GBARE_PATH    - Path to git repositories (default: /volume1/homes/\${GBARE_USER}/git)"
      echo "  GBARE_PROFILE - Active profile name (default: default)"
      echo "  GBARE_COLOR   - Enable color output (default: true)"
      echo ""
      echo "Config file: ~/.config/gbare/config"
      echo "  Format: INI-style with [profile_name] sections"
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
      echo "  gbare sync                       # Sync current repo"
      echo "  gbare backup ~/backups           # Backup all repos to ~/backups"
      echo "  gbare search myproject           # Search for repos matching 'myproject'"
      echo "  gbare profiles                   # List available profiles"
      echo "  gbare profile home               # Show 'home' profile settings"
      echo "  GBARE_PROFILE=work gbare create  # Use 'work' profile"
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
