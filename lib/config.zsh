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

# Refresh color definitions after configuration changes.
_gbare_init_colors() {
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
}

_gbare_init_colors

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
    _gbare_init_colors
    return 0
  fi

  # First check if the file has any profile sections
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line## }"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ '^\[([a-zA-Z0-9_-]+)\]$' ]]; then
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
    _gbare_init_colors
    return 0
  fi

  # Profile sections exist: only load the target profile
  local in_target_profile=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line## }"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ '^\[([a-zA-Z0-9_-]+)\]$' ]]; then
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

  _gbare_init_colors
  return 0
}

# Reload a changed selection from the settings present before the first load.
_gbare_ensure_config() {
  local config_file="${GBARE_CONFIG_FILE:a}"
  if [[ -z "${_GBARE_CONFIG_LOADED}" ]]; then
    typeset -ga _GBARE_CONFIG_BASELINE=(
      "$GBARE_USER" "$GBARE_HOST" "$GBARE_PORT" "$GBARE_PATH" "$GBARE_COLOR"
    )
  elif [[ "${_GBARE_LOADED_CONFIG_FILE}" == "$config_file" &&
          "${_GBARE_LOADED_PROFILE}" == "$GBARE_PROFILE" ]]; then
    return 0
  else
    GBARE_USER="${_GBARE_CONFIG_BASELINE[1]}"
    GBARE_HOST="${_GBARE_CONFIG_BASELINE[2]}"
    GBARE_PORT="${_GBARE_CONFIG_BASELINE[3]}"
    GBARE_PATH="${_GBARE_CONFIG_BASELINE[4]}"
    GBARE_COLOR="${_GBARE_CONFIG_BASELINE[5]}"
  fi

  _gbare_load_config
  typeset -g _GBARE_CONFIG_LOADED=true
  typeset -g _GBARE_LOADED_CONFIG_FILE="$config_file"
  typeset -g _GBARE_LOADED_PROFILE="$GBARE_PROFILE"
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
    line="${line%%#*}"
    line="${line## }"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ '^\[([a-zA-Z0-9_-]+)\]$' ]]; then
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
    line="${line%%#*}"
    line="${line## }"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ '^\[([a-zA-Z0-9_-]+)\]$' ]]; then
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

