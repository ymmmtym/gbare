#!/usr/bin/env zsh

# ========================================
# gbare Config File Tests
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"

oneTimeSetUp() {
  source "${SCRIPT_DIR}/gbare.zsh"
}

setUp() {
  # Reset config file path to temp location
  export GBARE_CONFIG_FILE="${_TEST_TMPDIR}/test_config"
  export GBARE_PROFILE="default"
  unset _GBARE_CONFIG_LOADED
  
  # Reset defaults
  export GBARE_USER="testuser"
  export GBARE_HOST="testhost"
  export GBARE_PORT=""
  export GBARE_PATH="/test/git"
  export GBARE_COLOR="true"
}

tearDown() {
  # Clean up test config file
  [[ -f "$GBARE_CONFIG_FILE" ]] && rm -f "$GBARE_CONFIG_FILE"
  unset _GBARE_CONFIG_LOADED
}

# ========================================
# Config File Loading Tests
# ========================================

test_load_config_no_file() {
  # Ensure config file doesn't exist
  [[ -f "$GBARE_CONFIG_FILE" ]] && rm -f "$GBARE_CONFIG_FILE"
  
  _gbare_load_config
  
  assertEquals "testuser" "$GBARE_USER" "Default user preserved"
  assertEquals "testhost" "$GBARE_HOST" "Default host preserved"
}

test_load_config_basic() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
GBARE_USER=configuser
GBARE_HOST=confighost
GBARE_PATH=/config/git
EOF
  
  _gbare_load_config
  
  assertEquals "configuser" "$GBARE_USER" "User loaded from config"
  assertEquals "confighost" "$GBARE_HOST" "Host loaded from config"
  assertEquals "/config/git" "$GBARE_PATH" "Path loaded from config"
}

test_load_config_without_profiles() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
GBARE_USER=noprofileuser
GBARE_HOST=noprofilehost
GBARE_PORT=3333
GBARE_PATH=/noprofile/git
EOF
  
  _gbare_load_config
  
  assertEquals "noprofileuser" "$GBARE_USER" "User loaded without profiles"
  assertEquals "noprofilehost" "$GBARE_HOST" "Host loaded without profiles"
  assertEquals "3333" "$GBARE_PORT" "Port loaded without profiles"
  assertEquals "/noprofile/git" "$GBARE_PATH" "Path loaded without profiles"
}

test_load_config_with_comments() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
# This is a comment
GBARE_USER=commentuser
# Another comment
GBARE_HOST=commenthost
EOF
  
  _gbare_load_config
  
  assertEquals "commentuser" "$GBARE_USER" "User loaded with comments"
  assertEquals "commenthost" "$GBARE_HOST" "Host loaded with comments"
}

test_load_config_with_port() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
GBARE_USER=portuser
GBARE_HOST=porthost
GBARE_PORT=2222
GBARE_PATH=/port/git
EOF
  
  _gbare_load_config
  
  assertEquals "2222" "$GBARE_PORT" "Port loaded from config"
}

# ========================================
# Profile Tests
# ========================================

test_load_config_with_profiles() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=defaultuser
GBARE_HOST=defaultserver

[work]
GBARE_USER=workuser
GBARE_HOST=workserver
GBARE_PORT=2222
EOF
  
  GBARE_PROFILE="default"
  _gbare_load_config
  
  assertEquals "defaultuser" "$GBARE_USER" "Default profile user"
  assertEquals "defaultserver" "$GBARE_HOST" "Default profile host"
}

test_load_config_work_profile() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=defaultuser
GBARE_HOST=defaultserver

[work]
GBARE_USER=workuser
GBARE_HOST=workserver
GBARE_PORT=2222
EOF
  
  GBARE_PROFILE="work"
  _gbare_load_config
  
  assertEquals "workuser" "$GBARE_USER" "Work profile user"
  assertEquals "workserver" "$GBARE_HOST" "Work profile host"
  assertEquals "2222" "$GBARE_PORT" "Work profile port"
}

test_load_config_with_commented_profile_headers() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]   # Default settings
GBARE_USER=defaultuser
GBARE_HOST=defaultserver
GBARE_PATH=/default/git

[work]	 	# Work settings
GBARE_USER=workuser
GBARE_HOST=workserver
GBARE_PORT=2222
EOF

  GBARE_PROFILE="default"
  _gbare_load_config

  assertEquals "defaultuser" "$GBARE_USER" "Commented default profile user"
  assertEquals "defaultserver" "$GBARE_HOST" "Commented default profile host"
  assertEquals "" "$GBARE_PORT" "Work port does not leak into default profile"
  assertEquals "/default/git" "$GBARE_PATH" "Commented default profile path"

  GBARE_PROFILE="work"
  GBARE_PATH="/test/git"
  _gbare_load_config

  assertEquals "workuser" "$GBARE_USER" "Commented work profile user"
  assertEquals "workserver" "$GBARE_HOST" "Commented work profile host"
  assertEquals "2222" "$GBARE_PORT" "Commented work profile port"
  assertEquals "/test/git" "$GBARE_PATH" "Default path does not leak into work profile"
}

test_load_config_profile_with_underscores() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[my_server]
GBARE_USER=myserveruser
GBARE_HOST=myserverhost
EOF
  
  GBARE_PROFILE="my_server"
  _gbare_load_config
  
  assertEquals "myserveruser" "$GBARE_USER" "Profile with underscores"
  assertEquals "myserverhost" "$GBARE_HOST" "Profile with underscores host"
}

test_list_profiles() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=defaultuser

[work]
GBARE_USER=workuser

[home]
GBARE_USER=homeuser
EOF
  
  local output=$(_gbare_list_profiles)
  
  assertContains "$output" "default" "Lists default profile"
  assertContains "$output" "work" "Lists work profile"
  assertContains "$output" "home" "Lists home profile"
  assertContains "$output" "active" "Shows active profile"
}

test_list_profiles_no_file() {
  [[ -f "$GBARE_CONFIG_FILE" ]] && rm -f "$GBARE_CONFIG_FILE"
  
  local result
  result=$(_gbare_list_profiles 2>&1)
  local exit_code=$?
  
  assertContains "$result" "No config file" "Shows no config file message"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_show_profile() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=defaultuser
GBARE_HOST=defaultserver
GBARE_PATH=/default/git

[work]
GBARE_USER=workuser
GBARE_HOST=workserver
GBARE_PORT=2222
EOF
  
  local output=$(_gbare_show_profile "work")
  
  assertContains "$output" "work" "Shows profile name"
  assertContains "$output" "workuser" "Shows work user"
  assertContains "$output" "workserver" "Shows work host"
  assertContains "$output" "2222" "Shows work port"
}

test_show_profile_not_found() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=defaultuser
EOF
  
  local result
  result=$(_gbare_show_profile "nonexistent" 2>&1)
  local exit_code=$?
  
  assertContains "$result" "not found" "Shows profile not found"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

# Exercise the public command in the same shell so cached state is retained.
test_command_reloads_changed_selection() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_USER=firstuser
GBARE_HOST=firsthost
GBARE_PORT=2222
GBARE_PATH=/first/git
GBARE_COLOR=false
[work]
GBARE_HOST=workhost
EOF
  gbare config >/dev/null
  assertEquals "2222" "$GBARE_PORT" "First selection loaded"

  GBARE_PROFILE=work gbare config >/dev/null
  assertEquals "workhost" "$GBARE_HOST" "Temporary profile selection loaded"
  assertEquals "testuser" "$GBARE_USER" "Omitted user restored from baseline"
  assertEquals "" "$GBARE_PORT" "Omitted port restored from baseline"
  assertEquals "/test/git" "$GBARE_PATH" "Omitted path restored from baseline"
  assertEquals "true" "$GBARE_COLOR" "Omitted color restored from baseline"

  gbare config >/dev/null
  assertEquals "firsthost" "$GBARE_HOST" "Returning from temporary profile reloads"
  GBARE_PROFILE=missing
  gbare config >/dev/null
  assertEquals "testhost" "$GBARE_HOST" "Missing profile uses clean baseline"

  GBARE_PROFILE=default
  gbare config >/dev/null
  local other_config="${_TEST_TMPDIR}/other_config"
  print -r -- 'GBARE_HOST=otherhost' > "$other_config"
  GBARE_CONFIG_FILE="$other_config" gbare config >/dev/null
  assertEquals "otherhost" "$GBARE_HOST" "Changed config path loaded"
  assertEquals "" "$GBARE_PORT" "Changed file does not inherit port"
  gbare config >/dev/null
  assertEquals "firsthost" "$GBARE_HOST" "Returning from temporary path reloads"

  GBARE_CONFIG_FILE="${_TEST_TMPDIR}/missing_config" gbare config >/dev/null
  assertEquals "testhost" "$GBARE_HOST" "Missing file uses clean baseline"
}

test_command_keeps_same_selection_cached() {
  print -r -- 'GBARE_HOST=firsthost' > "$GBARE_CONFIG_FILE"
  gbare config >/dev/null
  print -r -- 'GBARE_HOST=changedhost' > "$GBARE_CONFIG_FILE"
  gbare config >/dev/null
  assertEquals "firsthost" "$GBARE_HOST" "Unchanged selection remains cached"
}

test_completion_reloads_changed_selection() {
  cat > "$GBARE_CONFIG_FILE" <<EOF
[default]
GBARE_PORT=2222
[work]
GBARE_HOST=workhost
EOF
  # Stub completion's remote access and display; retain settings in this shell.
  local original_ssh="${functions[_gbare_ssh]}"
  _gbare_ssh() { :; }
  _describe() { :; }
  _gbare_repos
  assertEquals "2222" "$GBARE_PORT" "Completion loads first selection"
  GBARE_PROFILE=work
  _gbare_repos
  assertEquals "workhost" "$GBARE_HOST" "Completion reloads changed profile"
  assertEquals "" "$GBARE_PORT" "Completion clears omitted settings"
  functions[_gbare_ssh]="$original_ssh"
  unfunction _describe
}

# ========================================
# Validation Tests
# ========================================

test_validate_valid_config() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  export GBARE_PORT=""
  
  _gbare_validate_settings
  local exit_code=$?
  
  assertTrue "Valid config passes" "[[ $exit_code -eq 0 ]]"
}

test_validate_valid_config_with_port() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  export GBARE_PORT="2222"
  
  _gbare_validate_settings
  local exit_code=$?
  
  assertTrue "Valid config with port passes" "[[ $exit_code -eq 0 ]]"
}

test_validate_missing_user() {
  export GBARE_USER=""
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "GBARE_USER" "Error mentions missing user"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_validate_missing_host() {
  export GBARE_USER="validuser"
  export GBARE_HOST=""
  export GBARE_PATH="/valid/path"
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "GBARE_HOST" "Error mentions missing host"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_validate_missing_path() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH=""
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "GBARE_PATH" "Error mentions missing path"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_validate_invalid_port() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  export GBARE_PORT="abc"
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "GBARE_PORT" "Error mentions invalid port"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_validate_port_out_of_range_high() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  export GBARE_PORT="99999"
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "65535" "Error mentions port range"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

test_validate_port_zero() {
  export GBARE_USER="validuser"
  export GBARE_HOST="validhost"
  export GBARE_PATH="/valid/path"
  export GBARE_PORT="0"
  
  local result
  result=$(_gbare_validate_settings 2>&1)
  local exit_code=$?
  
  assertContains "$result" "GBARE_PORT" "Error mentions port out of range"
  assertTrue "Returns non-zero" "[[ $exit_code -ne 0 ]]"
}

# ========================================
# Updated Config Command Tests
# ========================================

test_config_shows_config_file() {
  local output=$(_gbare_config)
  assertContains "$output" "Config file" "Shows config file path"
}

test_config_shows_profile() {
  local output=$(_gbare_config)
  assertContains "$output" "Active profile" "Shows active profile"
}

# ========================================
# Run Tests
# ========================================

runAllTests
exit $?
