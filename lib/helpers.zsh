# ========================================
# gbare - Helper Functions
# ========================================

# Color definitions
: ${GBARE_COLOR:="true"}
if [[ "$GBARE_COLOR" == "true" ]] && [[ -t 1 ]]; then
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

# SSH コマンドを構築（ポート指定を適切に処理）
_gbare_ssh() {
  if [[ -n "$GBARE_PORT" ]]; then
    ssh -o LogLevel=ERROR -p ${GBARE_PORT} ${GBARE_USER}@${GBARE_HOST} "$@"
  else
    ssh -o LogLevel=ERROR ${GBARE_USER}@${GBARE_HOST} "$@"
  fi
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
