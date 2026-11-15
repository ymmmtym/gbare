# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# This file is kept for backward compatibility.
# New installations should use gbare.plugin.zsh which sources modular files from lib/.

# Check before using path modifiers that older zsh releases do not support.
if ! autoload -Uz is-at-least || ! is-at-least 5.0; then
  echo "gbare requires zsh 5.0 or later (current: ${ZSH_VERSION:-unknown})" >&2
  return 1
fi

local _gbare_root="${0:A:h}"
source "${_gbare_root}/lib/config.zsh"
source "${_gbare_root}/lib/helpers.zsh"
source "${_gbare_root}/lib/core.zsh"
source "${_gbare_root}/lib/completion.zsh"
